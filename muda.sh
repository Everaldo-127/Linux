#!/bin/bash

# Função para verificar a interface gráfica atual
check_current_desktop() {
    echo "Verificando a interface gráfica atual..."
    current_desktop=$(echo $XDG_CURRENT_DESKTOP)
    if [ -z "$current_desktop" ]; then
        echo "Nenhuma interface gráfica detectada."
        exit 1
    fi
    echo "A interface gráfica atual é: $current_desktop"
}

# Função para verificar e instalar pacotes necessários
install_packages() {
    local desktop_env=$1
    echo "Verificando pacotes necessários para $desktop_env..."

    if [ "$desktop_env" = "cinnamon" ]; then
        required_packages=(cinnamon cinnamon-desktop-data)
    elif [ "$desktop_env" = "gnome" ]; then
        required_packages=(gnome gnome-shell)
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

# Função para remover o gerenciador gráfico anterior
remove_previous_desktop() {
    echo "Removendo o gerenciador gráfico anterior..."
    
    if [ "$current_desktop" = "XFCE" ] || dpkg -l | grep -q 'xfce4'; then
        sudo apt remove --purge xfdesktop4 xfwm4 xfce4-panel xfce4-session xfce4-settings -y
    elif [ "$current_desktop" = "GNOME" ] || dpkg -l | grep -q 'gnome'; then
        sudo apt remove --purge gnome gnome-shell -y
    elif [ "$current_desktop" = "Cinnamon" ] || dpkg -l | grep -q 'cinnamon'; then
        sudo apt remove --purge cinnamon cinnamon-desktop-data -y
    fi
    
    sudo apt autoremove -y
}

# Atualiza o sistema
echo "Atualizando o sistema..."
sudo apt update && sudo apt upgrade -y

# Verifica a interface gráfica atual
check_current_desktop

# Opção de instalação ou rollback
echo "Escolha uma opção:"
echo "1 - Instalar Cinnamon"
echo "2 - Instalar GNOME"
echo "3 - Voltar para XFCE"
read -p "Digite o número da opção desejada (1, 2 ou 3): " choice

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
        echo "Reinstalando o XFCE..."
        sudo apt install -y xfdesktop4 xfwm4 xfce4-panel xfce4-session xfce4-settings
        remove_previous_desktop
        exit 0
        ;;
    *)
        echo "Opção inválida."
        exit 1
        ;;
esac

# Finaliza
echo "Instalação concluída. Você pode agora reiniciar o sistema."
