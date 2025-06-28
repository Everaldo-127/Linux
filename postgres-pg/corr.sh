#!/bin/bash
set -e

echo "[1/3] Baixando chave GPG do pgAdmin4 (modo seguro)..."
curl -fsSL https://www.pgadmin.org/static/packages_pgadmin_org.pub | gpg --dearmor | sudo tee /usr/share/keyrings/pgadmin.gpg > /dev/null

echo "[2/3] Adicionando repositório do pgAdmin4 (jammy)..."
echo "deb [signed-by=/usr/share/keyrings/pgadmin.gpg] https://ftp.postgresql.org/pub/pgadmin/pgadmin4/apt/jammy pgadmin4 main" | sudo tee /etc/apt/sources.list.d/pgadmin4.list > /dev/null

echo "[3/3] Atualizando pacotes..."
sudo apt update

