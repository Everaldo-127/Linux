# Criar pasta keyrings (se não existir)
sudo mkdir -p /etc/apt/keyrings

# Baixar e armazenar a chave corretamente
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc > /dev/null

# Atualizar o repositório do Docker para usar a chave no local correto
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu noble stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Atualizar pacotes
sudo apt update

