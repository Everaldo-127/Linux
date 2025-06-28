#!/bin/bash

# =============================================
# INSTALAÇÃO DO POSTGRESQL + PGADMIN 4 (VERSÃO CORRIGIDA)
# Compatível com Mint 22.1 Xia e Debian base
# =============================================

check_error() {
  if [ $? -ne 0 ]; then
    echo "[ERRO] Processo falhou: $1"
    exit 1
  fi
}

# Detectar codinome do sistema (Mint base Ubuntu)
CODENAME=$(lsb_release -cs)

# Ajustar para pgAdmin 4 que não suporta 'noble', usa 'jammy'
PGADMIN_CODENAME="$CODENAME"
if [[ "$CODENAME" == "noble" || "$CODENAME" == "xia" ]]; then
  PGADMIN_CODENAME="jammy"
  echo "[AVISO] Codinome '$CODENAME' não suportado pelo pgAdmin. Usando 'jammy' como base alternativa."
fi

echo "[1/6] Atualizando pacotes do sistema..."
sudo apt update -y
check_error "Falha ao atualizar pacotes."

echo "[2/6] Instalando dependências..."
sudo apt install -y curl gpg
check_error "Falha ao instalar dependências."

echo "[3/6] Configurando repositório do PostgreSQL..."
# Remove repositórios antigos antes para evitar conflito (opcional)
sudo rm -f /etc/apt/sources.list.d/pgdg.list
# Adiciona repositorio com filtro arquitetura amd64 para evitar warning i386
# Força uso de 'jammy' também para PostgreSQL, pois 'xia' não é suportado
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/postgresql-archive-keyring.gpg] https://apt.postgresql.org/pub/repos/apt jammy-pgdg main" \
  | sudo tee /etc/apt/sources.list.d/pgdg.list > /dev/null
curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg
sudo apt update
check_error "Falha ao configurar repositório do PostgreSQL."

echo "[4/6] Instalando PostgreSQL..."
sudo apt install -y postgresql postgresql-contrib
check_error "Falha ao instalar PostgreSQL."

echo "[5/6] Habilitando e iniciando o serviço PostgreSQL..."
sudo systemctl enable postgresql
sudo systemctl start postgresql
check_error "Falha ao iniciar o PostgreSQL."

echo "[6/6] Instalando pgAdmin 4..."
sudo rm -f /etc/apt/sources.list.d/pgadmin4.list
sudo curl -fsSL https://www.pgadmin.org/static/packages_pgadmin_org.pub | sudo gpg --dearmor -o /usr/share/keyrings/pgadmin-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/pgadmin-keyring.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/${PGADMIN_CODENAME} pgadmin4 main" | sudo tee /etc/apt/sources.list.d/pgadmin4.list > /dev/null
sudo apt update

# Instalar somente pgadmin4-desktop (evita dependência python3.10 do pgadmin4-server)
sudo apt install -y pgadmin4-desktop
check_error "Falha ao instalar pgAdmin 4."

echo "----------------------------------------"
echo "INSTALAÇÃO CONCLUÍDA COM SUCESSO!"
echo "----------------------------------------"
echo "POSTGRESQL:"
echo "- Serviço: sudo systemctl status postgresql"
echo "- Acessar: sudo -u postgres psql"
echo "PGADMIN 4:"
echo "- Executar: pgadmin4"
echo "----------------------------------------"

