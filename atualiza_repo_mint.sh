#!/bin/bash

# ========================================================================================================
# SCRIPT DE VERIFICAÇÃO, LIMPEZA E ATUALIZAÇÃO DOS REPOSITÓRIOS DO MINT 22.1 XIA
#
# DESCRIÇÃO:
# Este script realiza uma varredura, limpeza, backup e atualização dos repositórios configurados no Mint 22.1 Xia.
# Ele garante:
# - Execução como root;
# - Backup dos arquivos fontes;
# - Remoção de arquivos .sources malformados do cache APT;
# - Remoção de arquivos .sources conflitantes;
# - Remoção de duplicatas entre sources.list e arquivos .list.d;
# - Atualização do arquivo oficial mint-xia-official.list com repositórios Mint e Ubuntu Jammy;
# - Tratamento específico de pacotes com dependências quebradas para evitar erros de hold;
# - Atualização do sistema e limpeza;
# - Reinício dos serviços apt-daily;
# - Logging completo para auditoria.
# ========================================================================================================

LOGFILE="/var/log/atualiza_repos_mint_xia.log"
BACKUP_DIR="$HOME/backup_repos_$(date +%Y%m%d_%H%M%S)"
REPO_LIST="/etc/apt/sources.list.d/mint-xia-official.list"
SOURCES_LIST="/etc/apt/sources.list"

echo "=== INÍCIO DO PROCESSO DE ATUALIZAÇÃO - $(date) ===" | tee "$LOGFILE"

# Verifica permissão de root
if [[ $EUID -ne 0 ]]; then
  echo "Erro: este script precisa ser executado como root." | tee -a "$LOGFILE"
  exit 1
fi

# Criar backup
echo "Criando backup dos arquivos de configuração em $BACKUP_DIR ..." | tee -a "$LOGFILE"
mkdir -p "$BACKUP_DIR"
cp "$SOURCES_LIST" "$BACKUP_DIR/sources.list.bak" 2>/dev/null
[ -f "$REPO_LIST" ] && cp "$REPO_LIST" "$BACKUP_DIR/mint-xia-official.list.bak"

# Função: remover linhas duplicadas entre dois arquivos
remove_duplicatas() {
  local fonte="$1"
  local comparar="$2"
  grep -v -F -x -f <(grep -v '^#' "$comparar" | sed '/^\s*$/d') "$fonte" > "${fonte}.tmp" && mv "${fonte}.tmp" "$fonte"
}

# Remoção de .sources malformados do cache APT
echo "Removendo arquivos .sources malformados do cache APT..." | tee -a "$LOGFILE"
BAD_SOURCES=$(grep -rl "Malformed stanza" /var/lib/apt/lists 2>/dev/null)
if [ -z "$BAD_SOURCES" ]; then
  echo "Nenhum arquivo .sources malformado encontrado." | tee -a "$LOGFILE"
else
  for file in $BAD_SOURCES; do
    rm -f "$file"
    echo "Removido: $file" | tee -a "$LOGFILE"
  done
fi

# Remoção de arquivos .sources em /etc/apt/sources.list.d/
echo "Removendo arquivos .sources em /etc/apt/sources.list.d/ ..." | tee -a "$LOGFILE"
find /etc/apt/sources.list.d/ -name "*.sources" -exec rm -f {} \;

# Remover duplicatas entre sources.list e mint-xia-official.list
[ -f "$REPO_LIST" ] && remove_duplicatas "$SOURCES_LIST" "$REPO_LIST"

# Remover duplicatas entre todos os arquivos .list e o sources.list
for f in /etc/apt/sources.list.d/*.list; do
  [[ "$f" == "$REPO_LIST" ]] && continue
  [ ! -f "$f" ] && continue
  remove_duplicatas "$f" "$SOURCES_LIST"
done

# Atualizar repositórios oficiais do Mint Xia e Ubuntu Jammy
echo "Atualizando $REPO_LIST com repositórios oficiais Mint Xia e Ubuntu Jammy..." | tee -a "$LOGFILE"
cat > "$REPO_LIST" << EOF
deb http://packages.linuxmint.com xia main upstream import backport
deb http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-security main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-backports main restricted universe multiverse
EOF

# Remover duplicações internas
awk '!seen[$0]++' "$REPO_LIST" > "${REPO_LIST}.tmp" && mv "${REPO_LIST}.tmp" "$REPO_LIST"

# Atualização do sistema
echo "Atualizando lista de pacotes..." | tee -a "$LOGFILE"
apt update | tee -a "$LOGFILE"
echo "Atualização da lista concluída com sucesso." | tee -a "$LOGFILE"

# BLOCO CRÍTICO PARA RESOLVER PACOTES COM DEPENDÊNCIAS QUEBRADAS (hold)
echo "Tratando pacotes conflitantes problemáticos..." | tee -a "$LOGFILE"
apt-get remove --purge -y fonts-liberation fonts-liberation2 fonts-liberation-sans-narrow 2>/dev/null || true
apt-mark hold fonts-liberation fonts-liberation2 fonts-liberation-sans-narrow 2>/dev/null || true

echo "Removendo travas e corrigindo dependências..." | tee -a "$LOGFILE"
apt-mark unhold fonts-liberation fonts-liberation2 fonts-liberation-sans-narrow 2>/dev/null || true
dpkg --configure -a | tee -a "$LOGFILE"
apt-get install -f -y | tee -a "$LOGFILE"

echo "Executando upgrade com atenção às dependências..." | tee -a "$LOGFILE"
if ! apt upgrade -y | tee -a "$LOGFILE"; then
  echo "Erro detectado no upgrade, tentando corrigir..." | tee -a "$LOGFILE"
  apt-get -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" --fix-broken install -y | tee -a "$LOGFILE"
  apt upgrade -y | tee -a "$LOGFILE"
fi
echo "Atualização dos pacotes concluída com sucesso." | tee -a "$LOGFILE"

# Remoção de pacotes obsoletos
echo "Removendo pacotes obsoletos..." | tee -a "$LOGFILE"
apt autoremove -y | tee -a "$LOGFILE"
echo "Remoção de pacotes obsoletos concluída com sucesso." | tee -a "$LOGFILE"

# Reiniciar serviços do APT
echo "Reiniciando serviços apt-daily..." | tee -a "$LOGFILE"
systemctl daemon-reexec
systemctl restart apt-daily.service
systemctl restart apt-daily-upgrade.service

# Limpeza final
echo "Limpando arquivos temporários ..." | tee -a "$LOGFILE"
find /tmp -mindepth 1 -maxdepth 1 -exec rm -rf {} \;

echo "=== PROCESSO FINALIZADO COM SUCESSO - $(date) ===" | tee -a "$LOGFILE"
echo "Backup salvo em: $BACKUP_DIR" | tee -a "$LOGFILE"
echo "Log salvo em: $LOGFILE" | tee -a "$LOGFILE"

