#!/bin/bash

# ========================================================================================================
# SCRIPT PROFISSIONAL DE GERENCIAMENTO DE REPOSITÓRIOS - MINT 22.1 XIA (BASE UBUNTU 22.04 - JAMMY)
# Inclui todos os repositórios essenciais, fontes (deb-src) e parceiros (partner), com backup e limpeza.
# ========================================================================================================

LOGFILE="/var/log/atualiza_repos_mint_xia.log"
BACKUP_DIR="$HOME/backup_repos_$(date +%Y%m%d_%H%M%S)"
REPO_LIST="/etc/apt/sources.list.d/mint-xia-official.list"
SOURCES_LIST="/etc/apt/sources.list"

echo "=== INÍCIO DO PROCESSO - $(date) ===" | tee "$LOGFILE"

# Verifica se é root
if [[ $EUID -ne 0 ]]; then
  echo "Erro: Este script deve ser executado como root." | tee -a "$LOGFILE"
  exit 1
fi

# Backup de arquivos
echo "Backup de arquivos de repositório em $BACKUP_DIR..." | tee -a "$LOGFILE"
mkdir -p "$BACKUP_DIR"
cp "$SOURCES_LIST" "$BACKUP_DIR/sources.list.bak" 2>/dev/null
[ -f "$REPO_LIST" ] && cp "$REPO_LIST" "$BACKUP_DIR/mint-xia-official.list.bak"

# Função para remover duplicatas
remove_duplicatas() {
  local arquivo="$1"
  awk '!seen[$0]++' "$arquivo" > "${arquivo}.tmp" && mv "${arquivo}.tmp" "$arquivo"
}

# Limpeza de stanzas malformadas
echo "Removendo stanzas malformadas no cache APT..." | tee -a "$LOGFILE"
grep -rl "Malformed stanza" /var/lib/apt/lists 2>/dev/null | xargs -r rm -f

# Remoção de arquivos .sources inválidos
echo "Removendo arquivos *.sources inválidos em /etc/apt/sources.list.d/..." | tee -a "$LOGFILE"
find /etc/apt/sources.list.d/ -name "*.sources" -exec rm -f {} \;

# Reescrevendo o arquivo oficial com todos os repositórios possíveis
echo "Configurando repositórios completos no $REPO_LIST..." | tee -a "$LOGFILE"
cat << 'EOF' > "$REPO_LIST"
# Repositórios principais do Linux Mint 22.1 (Xia)
deb http://packages.linuxmint.com xia main upstream import backport

# Ubuntu 22.04 (Jammy) - Repositórios binários
deb http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-security main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-backports main restricted universe multiverse

# Ubuntu Partner - Softwares licenciados (Oracle Java, VMWare, etc)
deb http://archive.canonical.com/ubuntu jammy partner

# Repositórios de código-fonte (úteis para compilação)
deb-src http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu jammy-security main restricted universe multiverse
deb-src http://archive.ubuntu.com/ubuntu jammy-backports main restricted universe multiverse
EOF

# Remove duplicatas no próprio arquivo criado
remove_duplicatas "$REPO_LIST"

# Remove duplicatas em todos os outros arquivos .list
echo "Limpando duplicações em outros arquivos de repositório..." | tee -a "$LOGFILE"
for f in /etc/apt/sources.list.d/*.list; do
  [ -f "$f" ] && remove_duplicatas "$f"
done

# Remove duplicatas no sources.list principal
remove_duplicatas "$SOURCES_LIST"

# Atualização de repositórios
echo "Atualizando índice de pacotes..." | tee -a "$LOGFILE"
apt update | tee -a "$LOGFILE"

# Correção de pacotes quebrados
echo "Corrigindo dependências quebradas..." | tee -a "$LOGFILE"
apt-get install -f -y | tee -a "$LOGFILE"
dpkg --configure -a | tee -a "$LOGFILE"

# Upgrade completo
echo "Executando upgrade do sistema..." | tee -a "$LOGFILE"
if ! apt upgrade -y | tee -a "$LOGFILE"; then
  echo "Tentando correção automática de conflitos..." | tee -a "$LOGFILE"
  apt-get -o Dpkg::Options::="--force-confdef" \
          -o Dpkg::Options::="--force-confold" --fix-broken install -y | tee -a "$LOGFILE"
  apt upgrade -y | tee -a "$LOGFILE"
fi

# Remoção de pacotes obsoletos
echo "Removendo pacotes obsoletos..." | tee -a "$LOGFILE"
apt autoremove -y | tee -a "$LOGFILE"

# Reinício dos serviços apt
echo "Reiniciando serviços apt-daily..." | tee -a "$LOGFILE"
systemctl daemon-reexec
systemctl restart apt-daily.service
systemctl restart apt-daily-upgrade.service

# Limpeza final
echo "Limpando /tmp..." | tee -a "$LOGFILE"
find /tmp -mindepth 1 -maxdepth 1 -exec rm -rf {} \;

# Finalização
echo "=== PROCESSO FINALIZADO COM SUCESSO - $(date) ===" | tee -a "$LOGFILE"
echo "Backup salvo em: $BACKUP_DIR" | tee -a "$LOGFILE"
echo "Log salvo em: $LOGFILE" | tee -a "$LOGFILE"

