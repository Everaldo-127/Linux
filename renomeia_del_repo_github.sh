#!/bin/bash

LOG_FILE="/var/log/LOG_GITHUB.txt"

# Função para registrar no log com timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | sudo tee -a "$LOG_FILE" >/dev/null
}

# Verifica se script está rodando como root para poder escrever no log
if [[ $EUID -ne 0 ]]; then
    echo "Por favor, execute como root para que o script possa escrever no arquivo de log em /var/log."
    exit 1
fi

# Verifica se o Git está instalado
check_git() {
    if ! command -v git >/dev/null 2>&1; then
        echo "Git não está instalado. Abortando..."
        log "Git não está instalado. Abortando."
        exit 1
    else
        echo "Git está instalado."
        log "Git está instalado."
    fi
}

# Verifica as dependências necessárias (curl e jq)
check_dependencies() {
    local dependencies=("curl" "jq")
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            echo "Dependência $dep não está instalada. Abortando..."
            log "Dependência $dep não está instalada. Abortando."
            exit 1
        fi
    done
    echo "Todas as dependências estão instaladas."
    log "Todas as dependências estão instaladas."
}

# Solicita token de acesso pessoal para autenticação no GitHub
get_credentials() {
    read -p "Digite seu nome de usuário do GitHub: " GITHUB_USER
    read -sp "Digite seu token de acesso pessoal do GitHub (com permissão repo): " GITHUB_TOKEN
    echo
    if [[ -z "$GITHUB_USER" || -z "$GITHUB_TOKEN" ]]; then
        echo "Credenciais incompletas. Abortando."
        log "Credenciais incompletas. Abortando."
        exit 1
    fi
}

# Verifica se operação foi bem sucedida (HTTP 204 para DELETE, 200 para PATCH)
check_response() {
    local http_code=$1
    local operation=$2
    if [[ "$operation" == "delete" && "$http_code" == "204" ]]; then
        return 0
    elif [[ "$operation" == "rename" && "$http_code" == "200" ]]; then
        return 0
    else
        return 1
    fi
}

# Delete repositório no GitHub
delete_repository() {
    read -p "Digite o nome do repositório a ser excluído: " REPO_NAME
    if [[ -z "$REPO_NAME" ]]; then
        echo "Nome do repositório não pode ser vazio."
        return
    fi

    read -p "Confirma a exclusão do repositório '$REPO_NAME'? (y/n): " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        echo "Exclusão cancelada."
        log "Exclusão do repositório $REPO_NAME cancelada pelo usuário."
        return
    fi

    get_credentials

    local URL="https://api.github.com/repos/${GITHUB_USER}/${REPO_NAME}"

    echo "Processando exclusão do repositório '$REPO_NAME'..."

    # Executa DELETE e captura código HTTP
    HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE -u "${GITHUB_USER}:${GITHUB_TOKEN}" "$URL")

    if check_response "$HTTP_RESPONSE" "delete"; then
        echo "Repositório '$REPO_NAME' excluído com sucesso."
        log "Repositório '$REPO_NAME' excluído com sucesso pelo usuário $GITHUB_USER."
    else
        echo "Falha ao excluir o repositório. Código HTTP: $HTTP_RESPONSE"
        log "Falha ao excluir o repositório '$REPO_NAME'. Código HTTP: $HTTP_RESPONSE"
    fi
}

# Renomear repositório no GitHub
rename_repository() {
    read -p "Digite o nome atual do repositório: " OLD_NAME
    if [[ -z "$OLD_NAME" ]]; then
        echo "Nome antigo do repositório não pode ser vazio."
        return
    fi
    read -p "Digite o novo nome do repositório: " NEW_NAME
    if [[ -z "$NEW_NAME" ]]; then
        echo "Novo nome do repositório não pode ser vazio."
        return
    fi

    read -p "Confirma a renomeação do repositório '$OLD_NAME' para '$NEW_NAME'? (y/n): " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        echo "Renomeação cancelada."
        log "Renomeação de '$OLD_NAME' para '$NEW_NAME' cancelada pelo usuário."
        return
    fi

    get_credentials

    local URL="https://api.github.com/repos/${GITHUB_USER}/${OLD_NAME}"
    local DATA="{\"name\":\"${NEW_NAME}\"}"

    echo "Processando renomeação do repositório '$OLD_NAME' para '$NEW_NAME'..."

    HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH -u "${GITHUB_USER}:${GITHUB_TOKEN}" -H "Content-Type: application/json" -d "$DATA" "$URL")

    if check_response "$HTTP_RESPONSE" "rename"; then
        echo "Repositório renomeado com sucesso para '$NEW_NAME'."
        log "Repositório '$OLD_NAME' renomeado para '$NEW_NAME' com sucesso pelo usuário $GITHUB_USER."
    else
        echo "Falha ao renomear o repositório. Código HTTP: $HTTP_RESPONSE"
        log "Falha ao renomear o repositório '$OLD_NAME' para '$NEW_NAME'. Código HTTP: $HTTP_RESPONSE"
    fi
}

# Menu principal
main_menu() {
    while true; do
        echo ""
        echo "========================================"
        echo "Gerenciamento de Repositórios GitHub"
        echo "========================================"
        echo "1) Excluir repositório"
        echo "2) Renomear repositório"
        echo "3) Sair"
        read -p "Escolha uma opção [1-3]: " OPTION

        case "$OPTION" in
            1) delete_repository ;;
            2) rename_repository ;;
            3) echo "Saindo..."; exit 0 ;;
            *) echo "Opção inválida. Tente novamente." ;;
        esac
    done
}

# Execução principal
check_git
check_dependencies
main_menu
