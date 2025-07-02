#!/bin/bash

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

log "=== INÍCIO DO PROCESSO ==="

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

  # Clonar o repositório remoto para temporário
  git clone --depth=1 "https://$USUARIO_GITHUB:$TOKEN_PAT@github.com/$USUARIO_GITHUB/$REPO.git" "$TMP_DIR" || {
    log "❌ Falha ao clonar o repositório remoto."
    rm -rf "$TMP_DIR"
    exit 1
  }

  cd "$TMP_DIR" || exit 1
  git checkout main || git checkout -b main

  cd "$DIR_ATUAL" || exit 1

  # Sincronizar arquivos do diretório atual para temporário sem deletar arquivos no temporário
  log "📁 Sincronizando arquivos do diretório atual para diretório temporário..."
  rsync -a --exclude='.git' "$DIR_ATUAL"/ "$TMP_DIR"/

  cd "$TMP_DIR" || exit 1

  # Adicionar arquivos novos e modificados, sem remover arquivos remotos existentes
  git add .

  if git diff --cached --quiet; then
    log "⚠️ Sem alterações para commit."
  else
    git commit -m "$MENSAGEM_COMMIT [$(date '+%Y-%m-%d %H:%M:%S')]"
    log "✅ Commit realizado: $MENSAGEM_COMMIT"
  fi

  # Push para o repositório remoto
  git push origin main || {
    log "❌ Falha no push"
    rm -rf "$TMP_DIR"
    exit 1
  }

  cd "$DIR_ATUAL" || exit 1
  rm -rf "$TMP_DIR"
  log "🗑️ Diretório temporário removido"
  log "✅ Push realizado com sucesso!"
done

log "=== PROCESSO FINALIZADO ==="

