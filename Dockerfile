# ai-task-obs: auto-generated
FROM node:20.16.0-alpine AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

# ai-task-obs: pin pnpm to v8 — repo's pnpm-lock.yaml uses lockfileVersion 6.0
RUN npm i -g pnpm@8

FROM base AS build
COPY . /usr/src/app
WORKDIR /usr/src/app

RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --frozen-lockfile

RUN pnpm run -r build

# >>> ai-task-obs:apm >>>
# APM (OpenTelemetry) deps intentionally not installed here — pnpm's symlinked
# node_modules cannot be plain-copied into /app, and main.js wraps the require
# in try/catch so missing modules degrade to a non-fatal log.
# <<< ai-task-obs:apm <<<

RUN pnpm deploy --filter=server --prod /app
RUN pnpm deploy --filter=server --prod /app-sqlite

RUN cd /app && pnpm exec prisma generate

RUN cd /app-sqlite && \
    rm -rf ./prisma && \
    mv prisma-sqlite prisma && \
    pnpm exec prisma generate

FROM base AS app
COPY --from=build /app /app

# >>> ai-task-obs:apm >>>
# APM modules not bundled (see build stage); main.js handles missing deps.
# <<< ai-task-obs:apm <<<

# >>> ai-task-obs:entry >>>
# 复制入口薄壳到部署目录，docker-bootstrap.sh 通过 `node main.js` 启动
COPY --from=build /usr/src/app/main.js /app/main.js
# <<< ai-task-obs:entry <<<

WORKDIR /app

EXPOSE 8080

ENV NODE_ENV=production
ENV HOST="0.0.0.0"
ENV SERVER_ORIGIN_URL=""
ENV MAX_REQUEST_PER_MINUTE=60
ENV AUTH_CODE=""
ENV DATABASE_URL=""
# ai-task-obs: 默认端口与配置路径
ENV PORT=8080
ENV APP_CONFIG_PATH=/config/config.toml

RUN chmod +x ./docker-bootstrap.sh

CMD ["./docker-bootstrap.sh"]


# 默认构建目标 (没有 --target 时 docker 会构建最后一个 stage)。
# 部署链路使用 sqlite 变体，因为目标基础设施不提供 MySQL 实例。
FROM base AS app-sqlite
COPY --from=build /app-sqlite /app

# >>> ai-task-obs:apm >>>
# APM modules not bundled (see build stage); main.js handles missing deps.
# <<< ai-task-obs:apm <<<

# >>> ai-task-obs:entry >>>
# 复制入口薄壳到部署目录，docker-bootstrap.sh 通过 `node main.js` 启动
COPY --from=build /usr/src/app/main.js /app/main.js
# <<< ai-task-obs:entry <<<

WORKDIR /app

# ai-task-obs: 预创建 sqlite 数据目录（DATABASE_URL 默认指向 ../data/wewe-rss.db）
RUN mkdir -p /app/data

EXPOSE 8080

ENV NODE_ENV=production
ENV HOST="0.0.0.0"
ENV SERVER_ORIGIN_URL=""
ENV MAX_REQUEST_PER_MINUTE=60
ENV AUTH_CODE=""
ENV DATABASE_URL="file:../data/wewe-rss.db"
ENV DATABASE_TYPE="sqlite"
# ai-task-obs: 默认端口与配置路径
ENV PORT=8080
ENV APP_CONFIG_PATH=/config/config.toml

RUN chmod +x ./docker-bootstrap.sh

CMD ["./docker-bootstrap.sh"]