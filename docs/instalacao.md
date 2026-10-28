# Roteiro de instalação

DevOps na Prática — DCC / UFLA

Este roteiro cobre **Ubuntu/Debian**, **Fedora**, **macOS** e **Windows com
WSL2**. Instale na ordem em que as ferramentas aparecem aqui: o Docker é o
primeiro porque é o único que costuma dar trabalho de verdade.

Depois de cada bloco, rode `./scripts/check-ambiente.sh` para conferir o que já
está no lugar.

> **Windows puro, sem WSL2, não serve.** Comece pela [seção do
> WSL2](#0-windows-preparar-o-wsl2).

| Ferramenta  | Versão mínima | A partir da semana |
| ----------- | ------------- | ------------------ |
| `git`       | 2.30          | 1                  |
| `docker`    | 24.0          | 5                  |
| Compose     | v2            | 5                  |
| `kubectl`   | 1.28          | 10                 |
| `kind`      | 0.20          | 10                 |
| `helm`      | 3.12          | 12                 |
| `terraform` | 1.5           | 14                 |

Recomendado: **8 GB de RAM** e **20 GB** livres em disco. Se a sua máquina não
chega perto disso, fale com o professor **nesta semana** — há alternativas
(máquinas do laboratório, GitHub Codespaces, Killercoda) e todas exigem
combinar antes.

---

## 0. Windows: preparar o WSL2

Faça esta seção **antes** de qualquer outra. Depois dela, você segue as
instruções de **Ubuntu/Debian** dentro do WSL2 — o terminal do Ubuntu passa a
ser o seu ambiente de trabalho na disciplina.

1. Verifique se a **virtualização** está habilitada: Gerenciador de Tarefas →
   aba *Desempenho* → *CPU* → a linha "Virtualização" deve dizer *Habilitado*.
   Se disser *Desabilitado*, é preciso ligá-la na BIOS/UEFI (reinicie e procure
   por *Intel VT-x*, *AMD-V* ou *SVM Mode*). **Não deixe isso para a última
   hora.**

2. No PowerShell **como administrador**:

   ```powershell
   wsl --install -d Ubuntu
   ```

3. Reinicie o computador. Na primeira abertura do Ubuntu, crie o usuário e a
   senha do Linux (são independentes da conta do Windows).

4. Confirme que está no WSL **2**:

   ```powershell
   wsl -l -v          # a coluna VERSION precisa mostrar 2
   ```

5. Trabalhe sempre dentro do sistema de arquivos do Linux (`/home/<usuario>`),
   **não** em `/mnt/c/...`. Git e Docker ficam muito mais lentos no `/mnt/c`.

A partir daqui, abra o terminal do Ubuntu e siga a seção Ubuntu/Debian.

---

## 1. Git

### Ubuntu / Debian / WSL2

```bash
sudo apt update && sudo apt install -y git
```

### Fedora

```bash
sudo dnf install -y git
```

### macOS

```bash
brew install git
```

Se você ainda não tem o Homebrew:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### Configuração (todos os sistemas)

```bash
git config --global user.name  "Seu Nome Completo"
git config --global user.email "seu.email@estudante.ufla.br"
git config --global init.defaultBranch main
```

O nome e o e-mail aparecem em cada commit e são conferidos pela verificação
automática. Use o e-mail que você usa (ou vai usar) no GitHub.

---

## 2. Chave SSH para o GitHub

```bash
ssh-keygen -t ed25519 -C "seu.email@estudante.ufla.br"
```

Aceite o caminho padrão. A senha da chave (*passphrase*) é opcional, mas
recomendada.

```bash
cat ~/.ssh/id_ed25519.pub
```

Copie a saída inteira e cole em **GitHub → Settings → SSH and GPG keys → New SSH
key**. Depois teste:

```bash
ssh -T git@github.com
```

A resposta esperada é algo como
`Hi <seu-usuario>! You've successfully authenticated...`.

> No macOS, para não digitar a passphrase a cada push:
>
> ```bash
> ssh-add --apple-use-keychain ~/.ssh/id_ed25519
> ```

---

## 3. Docker

### Ubuntu / Debian / WSL2

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
```

**Feche o terminal e abra de novo** (ou rode `newgrp docker`) — o grupo só vale
em uma sessão nova. Sem isso você vai ver `permission denied` no socket.

No WSL2, se o daemon não subir sozinho:

```bash
sudo service docker start
```

### Fedora

```bash
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
sudo systemctl enable --now docker
sudo usermod -aG docker $USER
```

### macOS

```bash
brew install --cask docker
```

Depois **abra o Docker Desktop** pelo Launchpad e espere o ícone da baleia ficar
verde. O comando `docker` só responde com o Desktop rodando.

### Conferir

```bash
docker --version
docker compose version     # precisa ser v2 — repare que é "docker compose", sem hífen
docker run --rm hello-world
```

O `docker-compose` (com hífen) é a versão 1, descontinuada. Não serve.

---

## 4. kubectl

### Ubuntu / Debian / WSL2 / Fedora

```bash
curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
rm kubectl
```

### macOS

```bash
brew install kubectl
```

### Conferir

```bash
kubectl version --client
```

---

## 5. kind

O `kind` sobe um cluster Kubernetes dentro de containers Docker — é o que
usaremos a partir da Semana 10, sem nuvem paga.

### Ubuntu / Debian / WSL2 / Fedora

```bash
curl -Lo kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
sudo install -o root -g root -m 0755 kind /usr/local/bin/kind
rm kind
```

### macOS

```bash
brew install kind
```

### Conferir

```bash
kind --version
```

---

## 6. Helm

### Ubuntu / Debian / WSL2 / Fedora

```bash
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### macOS

```bash
brew install helm
```

### Conferir

```bash
helm version --short
```

---

## 7. Terraform

### Ubuntu / Debian / WSL2

```bash
wget -O- https://apt.releases.hashicorp.com/gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
  | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install -y terraform
```

### Fedora

```bash
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
sudo dnf install -y terraform
```

### macOS

```bash
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
```

### Conferir

```bash
terraform version
```

Documentação oficial, se algo mudar:
<https://developer.hashicorp.com/terraform/install>

---

## 8. Verificação final

```bash
./scripts/check-ambiente.sh
```

Tudo `[ok]` significa ambiente pronto. Linhas `[FALTA]` ou `[antigo]` trazem,
logo abaixo, o comando de instalação para o **seu** sistema. Linhas `[aviso]`
não impedem a entrega, mas leia com atenção — normalmente indicam pouca memória
ou pouco disco.

Salve o relatório, porque ele faz parte da entrega da Atividade 0:

```bash
./scripts/check-ambiente.sh | tee ambiente.txt
```

---

## Problemas comuns

**`permission denied` ao rodar `docker`**
Você não está no grupo `docker`, ou entrou nele mas não abriu uma sessão nova.
Rode `sudo usermod -aG docker $USER` e feche/abra o terminal.

**`Cannot connect to the Docker daemon`**
O Docker está instalado mas não está rodando. No macOS, abra o Docker Desktop.
No Linux, `sudo systemctl start docker`. No WSL2, `sudo service docker start`.

**`docker compose` não existe, mas `docker-compose` existe**
Você tem o Compose v1. Instale o plugin v2 (no Linux ele vem no
`docker-compose-plugin`; no macOS vem com o Docker Desktop).

**`git@github.com: Permission denied (publickey)`**
A chave SSH não foi cadastrada no GitHub, ou você cadastrou a chave privada em
vez da pública. O que vai para o GitHub é o conteúdo do arquivo terminado em
`.pub`.

**Tudo muito lento no WSL2**
Você provavelmente está trabalhando em `/mnt/c/...`. Mova o repositório para
`~/` dentro do Linux.

**O script diz `[aviso] RAM não consegui medir`**
Não é erro seu, e não bloqueia a entrega. Reporte no fórum informando o seu
sistema operacional.

Travou em algo que não está aqui? Poste no **fórum da Atividade 0** com: (1) o
que tentou, (2) o comando exato, (3) o erro completo em texto, (4) o que já
testou.
