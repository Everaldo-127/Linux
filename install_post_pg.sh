#!/bin/bash

# =============================================
# INSTALAÇÃO DO POSTGRESQL + PGADMIN 4 (VERSÃO CORRIGIDA)
# Compatível com Xubuntu 24.04 (kernel 6.8.0-60-generic)
# =============================================

# Função para verificar e tratar erros
check_error() {
  if [ $? -ne 0 ]; then
    echo "[ERRO] Processo falhou: $1"
    exit 1
  fi
}

# Atualizar repositórios
echo "[1/6] Atualizando pacotes do sistema..."
sudo apt update -y
check_error "Falha ao atualizar pacotes."

# Instalar dependências necessárias
echo "[2/6] Instalando dependências..."
sudo apt install -y curl gpg
check_error "Falha ao instalar dependências."

# Adicionar repositório do PostgreSQL
echo "[3/6] Configurando repositório do PostgreSQL..."
sudo sh -c 'echo "deb https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
curl https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg
sudo apt update
check_error "Falha ao configurar repositório do PostgreSQL."

# Instalar PostgreSQL
echo "[4/6] Instalando PostgreSQL..."
sudo apt install -y postgresql postgresql-contrib
check_error "Falha ao instalar PostgreSQL."

# Configurar PostgreSQL para iniciar com o sistema
echo "[5/6] Habilitando e iniciando o serviço PostgreSQL..."
sudo systemctl enable postgresql
sudo systemctl start postgresql
check_error "Falha ao iniciar o PostgreSQL."

# Instalar pgAdmin 4 (método alternativo)
echo "[6/6] Instalando pgAdmin 4..."
sudo curl -fsSL https://www.pgadmin.org/static/packages_pgadmin_org.pub | sudo gpg --dearmor -o /usr/share/keyrings/pgadmin-keyring.gpg
sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/pgadmin-keyring.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/$(lsb_release -cs) pgadmin4 main" > /etc/apt/sources.list.d/pgadmin4.list'
sudo apt update
sudo apt install -y pgadmin4-desktop
check_error "Falha ao instalar pgAdmin 4."

# Resumo da instalação
echo "----------------------------------------"
echo "INSTALAÇÃO CONCLUÍDA COM SUCESSO!"
echo "----------------------------------------"
echo "POSTGRESQL:"
echo "- Serviço: sudo systemctl status postgresql"
echo "- Acessar: sudo -u postgres psql"
echo "PGADMIN 4:"
echo "- Executar: pgadmin4"
echo "----------------------------------------"
