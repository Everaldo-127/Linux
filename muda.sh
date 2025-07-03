#!/bin/bash

set -euo pipefail

REPO_DIR="/etc/apt/sources.list.d"
BACKUP_DIR="/etc/apt/sources.list.d/backup_$(date +%Y%m%d_%H%M%S)"

# Backup dos arquivos .list
backup_lists() {
    echo "Criando backup dos arquivos .list em $BACKUP_DIR"
    sudo mkdir -p "$BACKUP_DIR"
    sudo cp "$REPO_DIR"/*.list "$BACKUP_DIR"/ 2>/dev/null || true
}

# Remove arquivos com extensões inválidas e duplicados de repositórios
clean_repo_files() {
    echo "Removendo arquivos com extensões inválidas em $REPO_DIR"
    sudo find "$REPO_DIR" -type f ! -name "*.list" -exec rm -f {} +

    echo "Eliminando arquivos .list duplicados"
    sudo bash -c "
        cd $REPO_DIR
        for file in *.list; do
            [ -f \"\$file\" ] || continue
            uniq_lines=\$(sort -u \"\$file\" | wc -l)
            total_lines=\$(wc -l < \"\$file\")
            if [ \"\$uniq_lines\" -lt \"\$total_lines\" ]; then
                sort -u \"\$file\" | sudo tee \"\$file\" > /dev/null
            fi
        done
    "
}

# Restaurar o arquivo official-package-repositories.list se vazio ou inexistente
restore_official_repo() {
    local file="$REPO_DIR/official-package-repositories.list"
    if [ ! -s "$file" ]; then
        echo "Restaurando official-package-repositories.list para Mint 22.1 Xia..."
        sudo tee "$file" > /dev/null <<EOF
# Linux Mint 22.1 "Xia" official package repositories

deb http://packages.linuxmint.com xia main upstream import backport

deb http://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-updates main restricted universe multiverse
deb http://archive.ubuntu.com/ubuntu jammy-backports main restricted universe multiverse

deb http://security.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse
EOF
    fi
}

# Atualiza repositórios após limpeza
apt_update() {
    echo "Atualizando os repositórios do sistema..."
    sudo apt update
}

# Desbloquear pacotes travados e corrigir pacotes quebrados
fix_held_and_broken_packages() {
    echo "Desbloqueando pacotes travados..."
    local held_packages
    held_packages=$(apt-mark showhold || true)
    if [ -n "$held_packages" ]; then
        sudo apt-mark unhold $held_packages
    fi

    echo "Configurando pacotes pendentes e corrigindo dependências quebradas..."
    sudo dpkg --configure -a
    sudo apt-get install -f -y
}

# Verifica interface gráfica
check_current_desktop() {
    echo "Verificando a interface gráfica atual..."
    current_desktop=$(echo "${XDG_CURRENT_DESKTOP:-unknown}" | tr '[:upper:]' '[:lower:]')
    if [ -z "$current_desktop" ] || [ "$current_desktop" = "unknown" ]; then
        echo "Nenhuma interface gráfica detectada."
        exit 1
    fi
    echo "A interface gráfica atual é: $current_desktop"
}

# Instalar pacotes conforme desktop escolhido
install_packages() {
    local desktop_env=$1
    echo "Verificando pacotes necessários para $desktop_env..."

    if [ "$desktop_env" = "cinnamon" ]; then
        required_packages=(cinnamon cinnamon-desktop-data)
    elif [ "$desktop_env" = "gnome" ]; then
        # Mint 22.1 usa 'gnome-session' ao invés de 'gnome-shell' direto
        required_packages=(ubuntu-session gnome-session gnome-shell)
    else
        echo "Ambiente de desktop desconhecido."
        exit 1
    fi

    for pkg in "${required_packages[@]}"; do
        if ! dpkg -l | grep -q "^ii  $pkg"; then
            echo "Pacote necessário: $pkg não está instalado. Instalando..."
            sudo apt install -y "$pkg" || { echo "Falha ao instalar $pkg"; exit 1; }
        else
            echo "Pacote $pkg já está instalado."
        fi
    done
}

# Remove gerenciador gráfico anterior
remove_previous_desktop() {
    echo "Removendo gerenciador gráfico anterior..."

    if [[ "$current_desktop" == *"xfce"* ]] || dpkg -l | grep -q 'xfce4'; then
        sudo apt remove --purge xfdesktop4 xfwm4 xfce4-panel xfce4-session xfce4-settings -y
    elif [[ "$current_desktop" == *"gnome"* ]] || dpkg -l | grep -q 'gnome'; then
        sudo apt remove --purge gnome ubuntu-session gnome-session gnome-shell -y
    elif [[ "$current_desktop" == *"cinnamon"* ]] || dpkg -l | grep -q 'cinnamon'; then
        sudo apt remove --purge cinnamon cinnamon-desktop-data -y
    fi

    sudo apt autoremove -y
}

# === Execução ===

backup_lists
clean_repo_files
restore_official_repo
apt_update
fix_held_and_broken_packages
check_current_desktop

echo "Escolha uma opção:"
echo "1 - Instalar Cinnamon"
echo "2 - Instalar GNOME"
echo "3 - Voltar para XFCE"
read -rp "Digite o número da opção desejada (1, 2 ou 3): " choice

case $choice in
    1)
        install_packages "cinnamon"
        remove_previous_desktop
        ;;
    2)
        install_packages "gnome"
        remove_previous_desktop
        ;;
    3)
        echo "Reinstalando XFCE..."
        sudo apt install -y xfdesktop4 xfwm4 xfce4-panel xfce4-session xfce4-settings
        remove_previous_desktop
        ;;
    *)
        echo "Opção inválida."
        exit 1
        ;;
esac

echo "Instalação concluída. Você pode reiniciar o sistema."

