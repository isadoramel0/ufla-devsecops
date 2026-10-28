#!/usr/bin/env bash
#
# check-ambiente.sh -- DevOps na Prática (DCC/UFLA)
#
# Verifica se a máquina tem tudo o que a disciplina exige, informa a versão
# encontrada e, quando algo falta, imprime o comando de instalação para o
# sistema operacional detectado.
#
#   Uso:  ./scripts/check-ambiente.sh
#         ./scripts/check-ambiente.sh | tee ambiente.txt   # salva o relatório
#
#   Código de saída:  0 = ambiente pronto
#                     1 = falta alguma coisa obrigatória
#
# Este script é, ele próprio, material didático: na Semana 4 nós o abrimos e
# discutimos cada construção usada aqui.
#
# ---------------------------------------------------------------------------

# Sem 'set -e': este script PRECISA continuar rodando mesmo quando um comando
# falha -- é exatamente disso que ele trata. Mas variável não declarada e falha
# no meio de um pipe continuam sendo erro.
set -uo pipefail

# ---------------------------------------------------------------------------
# Cores -- apenas quando a saída é um terminal de verdade.
# Sem esta checagem, um `| tee ambiente.txt` gravaria códigos ANSI no arquivo.
# ---------------------------------------------------------------------------
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    VERDE=$'\033[0;32m'; VERMELHO=$'\033[0;31m'; AMARELO=$'\033[0;33m'
    AZUL=$'\033[0;34m';  NEGRITO=$'\033[1m';     RESET=$'\033[0m'
else
    VERDE=''; VERMELHO=''; AMARELO=''; AZUL=''; NEGRITO=''; RESET=''
fi

FALTANDO=0   # conta itens obrigatórios ausentes ou desatualizados
AVISOS=0     # conta itens não bloqueantes

# ---------------------------------------------------------------------------
# Detecção do sistema operacional
# ---------------------------------------------------------------------------
detectar_so() {
    case "$(uname -s)" in
        Darwin) echo "macos" ;;
        Linux)
            # WSL2 se identifica pela string "microsoft" na versão do kernel
            if grep -qi microsoft /proc/version 2>/dev/null; then
                echo "wsl"
            elif [ -f /etc/os-release ]; then
                # shellcheck disable=SC1091
                . /etc/os-release
                case "${ID:-}${ID_LIKE:-}" in
                    *debian*|*ubuntu*) echo "debian" ;;
                    *fedora*|*rhel*)   echo "fedora" ;;
                    *arch*)            echo "arch"   ;;
                    *)                 echo "linux"  ;;
                esac
            else
                echo "linux"
            fi
            ;;
        *) echo "desconhecido" ;;
    esac
}

SO="$(detectar_so)"

# ---------------------------------------------------------------------------
# Comparação de versões -- retorna 0 (sucesso) se $1 >= $2
#
# Feito campo a campo em bash puro de propósito: `sort -V` não existe no sort
# do macOS, e este script precisa rodar igual nos três sistemas.
# ---------------------------------------------------------------------------
versao_ge() {
    local encontrada="$1" minima="$2"
    local IFS='.'
    # shellcheck disable=SC2206
    local -a v1=($encontrada) v2=($minima)
    local i a b
    for ((i = 0; i < ${#v2[@]}; i++)); do
        a="${v1[i]:-0}"; b="${v2[i]:-0}"
        a="${a%%[^0-9]*}"; b="${b%%[^0-9]*}"   # descarta sufixos tipo "-rc1"
        a="${a:-0}";      b="${b:-0}"
        ((10#$a > 10#$b)) && return 0
        ((10#$a < 10#$b)) && return 1
    done
    return 0
}

# Extrai o primeiro número no formato X.Y ou X.Y.Z da saída de um comando
extrair_versao() {
    grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n1
}

# ---------------------------------------------------------------------------
# Dicas de instalação por ferramenta e por sistema
# ---------------------------------------------------------------------------
dica_instalacao() {
    local ferramenta="$1"
    case "$ferramenta:$SO" in
        git:macos)          echo "brew install git" ;;
        git:debian|git:wsl) echo "sudo apt update && sudo apt install -y git" ;;
        git:fedora)         echo "sudo dnf install -y git" ;;

        docker:macos)       echo "brew install --cask docker   (e abra o Docker Desktop)" ;;
        docker:debian|docker:wsl)
                            echo "curl -fsSL https://get.docker.com | sudo sh && sudo usermod -aG docker \$USER" ;;
        docker:fedora)      echo "sudo dnf install -y docker-ce && sudo systemctl enable --now docker" ;;

        kubectl:macos)      echo "brew install kubectl" ;;
        kubectl:debian|kubectl:wsl|kubectl:fedora)
                            echo "curl -LO https://dl.k8s.io/release/\$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl && sudo install kubectl /usr/local/bin/" ;;

        kind:macos)         echo "brew install kind" ;;
        kind:debian|kind:wsl|kind:fedora)
                            echo "curl -Lo kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64 && sudo install kind /usr/local/bin/" ;;

        helm:macos)         echo "brew install helm" ;;
        helm:debian|helm:wsl|helm:fedora)
                            echo "curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash" ;;

        terraform:macos)    echo "brew tap hashicorp/tap && brew install hashicorp/tap/terraform" ;;
        terraform:debian|terraform:wsl|terraform:fedora)
                            echo "veja https://developer.hashicorp.com/terraform/install" ;;

        *)                  echo "consulte docs/instalacao.md" ;;
    esac
}

# ---------------------------------------------------------------------------
# Verificação de uma ferramenta
#   $1 nome  $2 comando de versão  $3 versão mínima
# ---------------------------------------------------------------------------
verificar() {
    local nome="$1" comando_versao="$2" minima="$3"
    local saida versao

    if ! command -v "$nome" >/dev/null 2>&1; then
        printf '%s[FALTA]%s   %-11s %s\n' "$VERMELHO" "$RESET" "$nome" "não encontrado"
        printf '            %s↳ instale com:%s %s\n' "$AMARELO" "$RESET" "$(dica_instalacao "$nome")"
        FALTANDO=$((FALTANDO + 1))
        return 1
    fi

    saida="$(eval "$comando_versao" 2>/dev/null)"
    versao="$(printf '%s' "$saida" | extrair_versao)"

    if [ -z "$versao" ]; then
        printf '%s[aviso]%s   %-11s instalado, mas não consegui ler a versão\n' \
               "$AMARELO" "$RESET" "$nome"
        AVISOS=$((AVISOS + 1))
        return 0
    fi

    if versao_ge "$versao" "$minima"; then
        printf '%s[ok]%s      %-11s %s\n' "$VERDE" "$RESET" "$nome" "$versao"
    else
        printf '%s[antigo]%s  %-11s %s  (mínima: %s)\n' \
               "$VERMELHO" "$RESET" "$nome" "$versao" "$minima"
        printf '            %s↳ atualize com:%s %s\n' "$AMARELO" "$RESET" "$(dica_instalacao "$nome")"
        FALTANDO=$((FALTANDO + 1))
    fi
}

# ---------------------------------------------------------------------------
# O Docker precisa estar instalado E rodando E acessível sem sudo.
# Os três erros são diferentes e têm soluções diferentes.
# ---------------------------------------------------------------------------
verificar_docker_daemon() {
    if ! command -v docker >/dev/null 2>&1; then
        printf '%s[--]%s      %-11s %s\n' "$AMARELO" "$RESET" "daemon" \
               "pulado: instale o Docker primeiro"
        return 0
    fi

    local erro
    if erro="$(docker info 2>&1 >/dev/null)"; then
        printf '%s[ok]%s      %-11s respondendo\n' "$VERDE" "$RESET" "daemon"
        return 0
    fi

    case "$erro" in
        *"permission denied"*|*"Got permission denied"*)
            printf '%s[FALTA]%s   %-11s sem permissão para o socket\n' \
                   "$VERMELHO" "$RESET" "daemon"
            printf '            %s↳ rode:%s sudo usermod -aG docker $USER  %s(e refaça o login)%s\n' \
                   "$AMARELO" "$RESET" "$AMARELO" "$RESET"
            ;;
        *)
            printf '%s[FALTA]%s   %-11s instalado, mas não está rodando\n' \
                   "$VERMELHO" "$RESET" "daemon"
            if [ "$SO" = "macos" ]; then
                printf '            %s↳ abra o Docker Desktop e aguarde ficar verde%s\n' \
                       "$AMARELO" "$RESET"
            else
                printf '            %s↳ rode:%s sudo systemctl start docker\n' "$AMARELO" "$RESET"
            fi
            ;;
    esac
    FALTANDO=$((FALTANDO + 1))
}

# O Compose v2 é subcomando do docker; o antigo `docker-compose` não serve
verificar_compose() {
    if ! command -v docker >/dev/null 2>&1; then
        printf '%s[--]%s      %-11s %s\n' "$AMARELO" "$RESET" "compose" \
               "pulado: vem junto com o Docker"
        return 0
    fi

    local versao
    versao="$(docker compose version 2>/dev/null | extrair_versao)"
    if [ -n "$versao" ] && versao_ge "$versao" "2.0"; then
        printf '%s[ok]%s      %-11s %s\n' "$VERDE" "$RESET" "compose" "$versao"
    else
        printf '%s[FALTA]%s   %-11s Compose v2 ausente\n' "$VERMELHO" "$RESET" "compose"
        printf '            %s↳ precisamos de "docker compose" (v2), não do antigo "docker-compose"%s\n' \
               "$AMARELO" "$RESET"
        FALTANDO=$((FALTANDO + 1))
    fi
}

# ---------------------------------------------------------------------------
# Memória e disco
# ---------------------------------------------------------------------------
verificar_recursos() {
    local ram_gb='' disco_gb='' bytes

    if [ "$SO" = "macos" ]; then
        # sysctl vive em /usr/sbin, que nem sempre está no PATH
        bytes="$( { command -v sysctl >/dev/null 2>&1 && sysctl -n hw.memsize; } 2>/dev/null \
                  || /usr/sbin/sysctl -n hw.memsize 2>/dev/null )"
        [ -n "$bytes" ] && ram_gb=$(( bytes / 1024 / 1024 / 1024 ))
    elif [ -r /proc/meminfo ]; then
        ram_gb="$(awk '/MemTotal/ {printf "%d", $2/1024/1024}' /proc/meminfo 2>/dev/null)"
    fi

    # -P força o formato POSIX: uma linha por sistema de arquivos, campos fixos
    disco_gb="$(df -Pk . 2>/dev/null | awk 'NR==2 {printf "%d", $4/1024/1024}')"

    # Não sabemos medir != a máquina tem zero. Dizer "0 GB" mandaria o aluno
    # procurar o professor por causa de uma falha do próprio script.
    if [ -z "$ram_gb" ]; then
        printf '%s[aviso]%s   %-11s não consegui medir neste sistema\n' \
               "$AMARELO" "$RESET" "RAM"
        AVISOS=$((AVISOS + 1))
    elif [ "$ram_gb" -ge 8 ]; then
        printf '%s[ok]%s      %-11s %s GB\n' "$VERDE" "$RESET" "RAM" "$ram_gb"
    elif [ "$ram_gb" -ge 4 ]; then
        printf '%s[aviso]%s   %-11s %s GB  (recomendado: 8 GB a partir da Semana 10)\n' \
               "$AMARELO" "$RESET" "RAM" "$ram_gb"
        AVISOS=$((AVISOS + 1))
    else
        printf '%s[aviso]%s   %-11s %s GB  (procure o professor nesta semana)\n' \
               "$AMARELO" "$RESET" "RAM" "$ram_gb"
        AVISOS=$((AVISOS + 1))
    fi

    if [ -z "$disco_gb" ]; then
        printf '%s[aviso]%s   %-11s não consegui medir neste sistema\n' \
               "$AMARELO" "$RESET" "disco"
        AVISOS=$((AVISOS + 1))
    elif [ "$disco_gb" -ge 20 ]; then
        printf '%s[ok]%s      %-11s %s GB livres\n' "$VERDE" "$RESET" "disco" "$disco_gb"
    else
        printf '%s[aviso]%s   %-11s %s GB livres  (recomendado: 20 GB)\n' \
               "$AMARELO" "$RESET" "disco" "$disco_gb"
        AVISOS=$((AVISOS + 1))
    fi
}

# Git configurado é pré-requisito para a primeira entrega
verificar_config_git() {
    command -v git >/dev/null 2>&1 || return 0

    local nome email
    nome="$(git config --global user.name  2>/dev/null || true)"
    email="$(git config --global user.email 2>/dev/null || true)"

    if [ -n "$nome" ] && [ -n "$email" ]; then
        printf '%s[ok]%s      %-11s %s <%s>\n' "$VERDE" "$RESET" "git config" "$nome" "$email"
    else
        printf '%s[FALTA]%s   %-11s nome ou e-mail não configurados\n' \
               "$VERMELHO" "$RESET" "git config"
        printf '            %s↳ rode:%s git config --global user.name "Seu Nome"\n' "$AMARELO" "$RESET"
        printf '            %s     %s git config --global user.email "voce@estudante.ufla.br"\n' "$AMARELO" "$RESET"
        FALTANDO=$((FALTANDO + 1))
    fi
}

# ---------------------------------------------------------------------------
# Execução
# ---------------------------------------------------------------------------
printf '\n%s== Verificação de ambiente -- DevOps na Prática ==%s\n' "$NEGRITO$AZUL" "$RESET"
printf 'Sistema detectado: %s\n\n' "$SO"

printf '%s-- Ferramentas --%s\n' "$NEGRITO" "$RESET"
verificar git       'git --version'             '2.30'
verificar docker    'docker --version'          '24.0'
verificar kubectl   'kubectl version --client'  '1.28'
verificar kind      'kind --version'            '0.20'
verificar helm      'helm version --short'      '3.12'
verificar terraform 'terraform version'         '1.5'

printf '\n%s-- Docker em funcionamento --%s\n' "$NEGRITO" "$RESET"
verificar_docker_daemon
verificar_compose

printf '\n%s-- Configuração --%s\n' "$NEGRITO" "$RESET"
verificar_config_git

printf '\n%s-- Recursos da máquina --%s\n' "$NEGRITO" "$RESET"
verificar_recursos

# ---------------------------------------------------------------------------
# Veredito
# ---------------------------------------------------------------------------
printf '\n'
if [ "$FALTANDO" -eq 0 ]; then
    printf '%sAmbiente pronto. Bom semestre!%s\n' "$VERDE$NEGRITO" "$RESET"
    [ "$AVISOS" -gt 0 ] && printf '%s(%d aviso(s) acima -- não impedem a entrega, mas leia com atenção.)%s\n' \
                                  "$AMARELO" "$AVISOS" "$RESET"
    printf '\nPróximo passo: crie o arquivo alunos/<seu-usuario>.md e abra o Pull Request.\n\n'
    exit 0
else
    printf '%sFaltam %d item(ns) obrigatório(s).%s\n' "$VERMELHO$NEGRITO" "$FALTANDO" "$RESET"
    printf 'Resolva os itens marcados como [FALTA] ou [antigo] e rode este script de novo.\n'
    printf '\nTravou? Poste no fórum da Atividade 0 no campus virtual com:\n'
    printf '  (1) o que tentou  (2) o comando exato  (3) o erro completo, em texto  (4) o que já testou\n\n'
    exit 1
fi
