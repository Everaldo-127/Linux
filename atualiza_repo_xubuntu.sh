#!/bin/bash

# ========================================================================================================
# SCRIPT DE VERIFICAÇÃO, LIMPEZA E ATUALIZAÇÃO DOS REPOSITÓRIOS DO XUBUNTU 24.04 (MINIMAL)
#
# DESCRIÇÃO:
# Este script realiza uma varredura, limpeza e correção completa nos repositórios configurados no sistema
# Xubuntu 24.04 minimal. Ele:
# - Verifica e exige execução como root;
# - Cria backup dos arquivos atuais antes de qualquer modificação;
# - Remove arquivos `.sources` malformados do cache APT;
# - Remove arquivos `.sources` em `/etc/apt/sources.list.d/` que possam causar conflito;
# - Remove entradas duplicadas entre `/etc/apt/sources.list` e qualquer `.list`;
# - Cria ou atualiza o arquivo `/etc/apt/sources.list.d/xubuntu-minimal.list` com os repositórios oficiais;
# - Garante que não haja duplicatas internas nos arquivos;
# - Atualiza, faz upgrade e limpa pacotes do sistema;
# - Reinicia serviços apt relacionados;
# - Gera log e backup para auditoria em /var/log e ~/backup_repos_*/.
# ========================================================================================================

LOGFILE="/var/log/atualiza_repos_xubuntu_minimal.log"
BACKUP_DIR="$HOME/backup_repos_$(date +%Y%m%d_%H%M%S)"
REPO_LIST="/etc/apt/sources.list.d/xubuntu-minimal.list"
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
[ -f "$REPO_LIST" ] && cp "$REPO_LIST" "$BACKUP_DIR/xubuntu-minimal.list.bak"

# Função: remover linhas duplicadas entre dois arquivos
remove_duplicatas() {
  local fonte="$1"
  local comparar="$2"
  grep -v -F -x -f <(grep -v '^#' "$comparar" | sed '/^\s*$/d') "$fonte" > "${fonte}.tmp" && mv "${fonte}.tmp" "$fonte"
}

# Remoção de .sources malformados do cache do APT
echo "Removendo arquivos .sources malformados do cache APT..." | tee -a "$LOGFILE"
BAD_SOURCES=$(grep -rl "Malformed stanza" /var/lib/apt/lists 2>/dev/null)
for file in $BAD_SOURCES; do
  rm -f "$file"
  echo "Removido: $file" | tee -a "$LOGFILE"
done

# Remoção de arquivos .sources em /etc/apt/sources.list.d/
echo "Removendo arquivos .sources do diretório de fontes..." | tee -a "$LOGFILE"
find /etc/apt/sources.list.d/ -name "*.sources" -exec rm -f {} \;

# Remover duplicatas entre sources.list e xubuntu-minimal.list
[ -f "$REPO_LIST" ] && remove_duplicatas "$SOURCES_LIST" "$REPO_LIST"

# Remover duplicatas entre todos os arquivos .list e o sources.list
for f in /etc/apt/sources.list.d/*.list; do
  [[ "$f" == "$REPO_LIST" ]] && continue
  [ ! -f "$f" ] && continue
  remove_duplicatas "$f" "$SOURCES_LIST"
done

# Criar ou sobrescrever o arquivo de repositório minimal oficial
echo "Atualizando $REPO_LIST com repositórios oficiais..." | tee -a "$LOGFILE"
cat > "$REPO_LIST" << EOF
deb http://archive.ubuntu.com/ubuntu/ jammy main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ jammy-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu/ jammy-backports main restricted universe multiverse
EOF

# Remover duplicações internas
awk '!seen[$0]++' "$REPO_LIST" > "${REPO_LIST}.tmp" && mv "${REPO_LIST}.tmp" "$REPO_LIST"

# Atualização do sistema
echo "Atualizando lista de pacotes..." | tee -a "$LOGFILE"
apt update | tee -a "$LOGFILE"

echo "Atualizando pacotes instalados..." | tee -a "$LOGFILE"
apt upgrade -y | tee -a "$LOGFILE"

echo "Removendo pacotes obsoletos..." | tee -a "$LOGFILE"
apt autoremove -y | tee -a "$LOGFILE"

# Reiniciar serviços do APT
echo "Reiniciando serviços relacionados ao APT..." | tee -a "$LOGFILE"
systemctl daemon-reload
systemctl restart apt-daily.service
systemctl restart apt-daily-upgrade.service

echo "=== PROCESSO FINALIZADO COM SUCESSO - $(date) ===" | tee -a "$LOGFILE"
echo "Backup salvo em: $BACKUP_DIR"
echo "Log salvo em: $LOGFILE"

