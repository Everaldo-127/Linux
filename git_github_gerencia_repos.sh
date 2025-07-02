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
    local dependencies=("curl" "jq" "rsync")
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

# Verifica se operação foi bem sucedida
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

# Criar repositório no GitHub
create_repository() {
    get_credentials

    read -p "Digite o nome do novo repositório: " REPO_NAME
    if [[ -z "$REPO_NAME" ]]; then
        echo "Nome do repositório não pode ser vazio."
        return
    fi

    read -p "Digite uma descrição para o repositório (opcional): " REPO_DESC
    read -p "O repositório será privado? (y/n): " IS_PRIVATE

    if [[ "$IS_PRIVATE" == "y" || "$IS_PRIVATE" == "Y" ]]; then
        PRIVATE_FLAG=true
    else
        PRIVATE_FLAG=false
    fi

    local URL="https://api.github.com/user/repos"
    local DATA="{\"name\":\"${REPO_NAME}\",\"description\":\"${REPO_DESC}\",\"private\":${PRIVATE_FLAG}}"

    echo "Criando repositório '$REPO_NAME'..."

    HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X POST -u "${GITHUB_USER}:${GITHUB_TOKEN}" \
        -H "Content-Type: application/json" -d "$DATA" "$URL")

    if [[ "$HTTP_RESPONSE" == "201" ]]; then
        echo "Repositório '$REPO_NAME' criado com sucesso."
        log "Repositório '$REPO_NAME' criado com sucesso pelo usuário $GITHUB_USER."
    else
        echo "Falha ao criar o repositório. Código HTTP: $HTTP_RESPONSE"
        log "Falha ao criar o repositório '$REPO_NAME'. Código HTTP: $HTTP_RESPONSE"
    fi
}

# Renomear repositório
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

    HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X PATCH -u "${GITHUB_USER}:${GITHUB_TOKEN}" \
        -H "Content-Type: application/json" -d "$DATA" "$URL")

    if check_response "$HTTP_RESPONSE" "rename"; then
        echo "Repositório renomeado com sucesso para '$NEW_NAME'."
        log "Repositório '$OLD_NAME' renomeado para '$NEW_NAME' com sucesso."
    else
        echo "Falha ao renomear o repositório. Código HTTP: $HTTP_RESPONSE"
        log "Falha ao renomear o repositório '$OLD_NAME'."
    fi
}

# Excluir repositório
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

    HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE -u "${GITHUB_USER}:${GITHUB_TOKEN}" "$URL")

    if check_response "$HTTP_RESPONSE" "delete"; then
        echo "Repositório '$REPO_NAME' excluído com sucesso."
        log "Repositório '$REPO_NAME' excluído com sucesso."
    else
        echo "Falha ao excluir o repositório. Código HTTP: $HTTP_RESPONSE"
        log "Falha ao excluir o repositório '$REPO_NAME'."
    fi
}

# Clonar repositório localmente
clonar_repository() {
    get_credentials

    read -p "Digite o nome do repositório a ser clonado: " REPO_NAME
    if [[ -z "$REPO_NAME" ]]; then
        echo "Nome do repositório não pode ser vazio."
        return
    fi

    read -p "Digite o diretório de destino (ou deixe em branco para usar o nome do repositório): " DEST_DIR
    [[ -z "$DEST_DIR" ]] && DEST_DIR="$REPO_NAME"

    local REPO_URL="https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${REPO_NAME}.git"

    echo "Clonando repositório '$REPO_NAME' para '$DEST_DIR'..."
    log "Clonando repositório '$REPO_NAME' para '$DEST_DIR'."

    if git clone "$REPO_URL" "$DEST_DIR"; then
        echo "Repositório clonado com sucesso."
        log "Repositório '$REPO_NAME' clonado com sucesso no diretório '$DEST_DIR'."
    else
        echo "Erro ao clonar o repositório."
        log "Erro ao clonar o repositório '$REPO_NAME'."
    fi
}

# Enviar arquivos para repositórios GitHub
enviar_para_github() {
    DIR_ATUAL=$(pwd)
    log "Diretório de execução: $DIR_ATUAL"

    read -p "Usuário do GitHub: " USUARIO_GITHUB
    read -sp "Token de acesso pessoal (PAT) com permissão 'repo': " TOKEN_PAT
    echo
    read -p "Digite os nomes dos repositórios (separados por espaço): " REPOSITORIOS
    read -p "Mensagem base do commit: " MENSAGEM_COMMIT

    for REPO in $REPOSITORIOS; do
        log "📂 Processando repositório: $REPO"

        TMP_DIR=$(mktemp -d)
        log "🌐 Diretório temporário criado: $TMP_DIR"

        git clone --depth=1 "https://${USUARIO_GITHUB}:${TOKEN_PAT}@github.com/${USUARIO_GITHUB}/${REPO}.git" "$TMP_DIR" || {
            log "❌ Falha ao clonar o repositório remoto."
            rm -rf "$TMP_DIR"
            continue
        }

        cd "$TMP_DIR" || continue
        git checkout main || git checkout -b main
        cd "$DIR_ATUAL" || continue

        log "📁 Sincronizando arquivos do diretório atual para diretório temporário..."
        rsync -a --exclude='.git' "$DIR_ATUAL"/ "$TMP_DIR"/

        cd "$TMP_DIR" || continue
        git add .

        if git diff --cached --quiet; then
            log "⚠️ Sem alterações para commit."
        else
            git commit -m "$MENSAGEM_COMMIT [$(date '+%Y-%m-%d %H:%M:%S')]"
            log "✅ Commit realizado: $MENSAGEM_COMMIT"
        fi

        git push origin main || {
            log "❌ Falha no push"
            rm -rf "$TMP_DIR"
            continue
        }

        cd "$DIR_ATUAL" || continue
        rm -rf "$TMP_DIR"
        log "🗑️ Diretório temporário removido"
        log "✅ Push realizado com sucesso!"
    done

    log "=== ENVIO FINALIZADO ==="
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
        echo "3) Criar repositório"
        echo "4) Clonar repositório localmente"
        echo "5) Enviar arquivos para repositório"
        echo "6) Sair"
        read -p "Escolha uma opção [1-6]: " OPTION

        case "$OPTION" in
            1) delete_repository ;;
            2) rename_repository ;;
            3) create_repository ;;
            4) clonar_repository ;;
            5) enviar_para_github ;;
            6) echo "Saindo..."; exit 0 ;;
            *) echo "Opção inválida. Tente novamente." ;;
        esac
    done
}

# Execução principal
check_git
check_dependencies
main_menu

