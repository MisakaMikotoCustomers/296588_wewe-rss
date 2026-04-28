
#!/bin/sh
# ai-task-obs: auto-generated
# ENVIRONEMTN from docker-compose.yaml doesn't get through to subprocesses
# Need to explicit pass DATABASE_URL here, otherwise migration doesn't work

# >>> ai-task-obs:entry >>>
# 读取 /config/config.toml 并设置环境变量（如果存在）
CONFIG_PATH="${APP_CONFIG_PATH:-/config/config.toml}"
if [ -f "$CONFIG_PATH" ]; then
  echo "[ai-task-obs] Loading config from $CONFIG_PATH"

  # 读取 [database] 配置
  DB_HOST=$(grep -E '^host\s*=' "$CONFIG_PATH" 2>/dev/null | head -1 | cut -d= -f2 | tr -d ' "')
  DB_PORT=$(grep -E '^port\s*=' "$CONFIG_PATH" 2>/dev/null | head -1 | cut -d= -f2 | tr -d ' "')
  DB_USERNAME=$(grep -E '^username\s*=' "$CONFIG_PATH" 2>/dev/null | head -1 | cut -d= -f2 | tr -d ' "')
  DB_PASSWORD=$(grep -E '^password\s*=' "$CONFIG_PATH" 2>/dev/null | head -1 | cut -d= -f2 | tr -d ' "')
  DB_NAME=$(grep -E '^name\s*=' "$CONFIG_PATH" 2>/dev/null | head -1 | cut -d= -f2 | tr -d ' "')

  if [ -n "$DB_HOST" ] && [ -n "$DB_NAME" ]; then
    DB_URL="mysql://${DB_USERNAME:-root}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT:-3306}/${DB_NAME}"
    DATABASE_URL="${DATABASE_URL:-$DB_URL}"
    echo "[ai-task-obs] Using database from config: $DB_HOST"
  fi

  # 读取端口配置
  SERVER_PORT=$(grep -A20 '^\[server\]' "$CONFIG_PATH" 2>/dev/null | grep -E '^port\s*=' | head -1 | cut -d= -f2 | tr -d ' "')
  if [ -n "$SERVER_PORT" ]; then
    export PORT="$SERVER_PORT"
    echo "[ai-task-obs] Using port from config: $SERVER_PORT"
  fi

  # >>> ai-task-obs:rum >>>
  # 生成 /app/config.json 供前端 RUM SDK 使用
  RUM_ENABLED=$(grep -A20 '^\[rum\]' "$CONFIG_PATH" 2>/dev/null | grep -E '^enabled\s*=' | head -1 | cut -d= -f2 | tr -d ' "')
  RUM_ID=$(grep -A20 '^\[rum\]' "$CONFIG_PATH" 2>/dev/null | grep -E '^id\s*=' | head -1 | cut -d= -f2 | tr -d ' "')
  RUM_ENV=$(grep -A20 '^\[rum\]' "$CONFIG_PATH" 2>/dev/null | grep -E '^env\s*=' | head -1 | cut -d= -f2 | tr -d ' "')
  RUM_VERSION=$(grep -A20 '^\[rum\]' "$CONFIG_PATH" 2>/dev/null | grep -E '^version\s*=' | head -1 | cut -d= -f2 | tr -d ' "')

  if [ -n "$RUM_ID" ]; then
    cat > /app/config.json <<EOF
{
  "rum": {
    "enabled": ${RUM_ENABLED:-false},
    "id": "${RUM_ID}",
    "env": "${RUM_ENV:-production}",
    "version": "${RUM_VERSION:-1.0.0}"
  }
}
EOF
    echo "[ai-task-obs] RUM config generated: id=$RUM_ID"
  else
    echo "[ai-task-obs] RUM not configured, skipping config.json"
  fi
  # <<< ai-task-obs:rum <<<
fi
# <<< ai-task-obs:entry <<<

# Run migrations
DATABASE_URL=${DATABASE_URL} npx prisma migrate deploy
# start app via main.js shim for observability
DATABASE_URL=${DATABASE_URL} node main.js