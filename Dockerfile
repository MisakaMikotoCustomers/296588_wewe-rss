# ai-task-obs: auto-generated
FROM node:20.16.0-alpine AS base
ENV PNPM_HOME="/pnpm"
ENV PATH="$PNPM_HOME:$PATH"

RUN npm i -g pnpm

FROM base AS build
COPY . /usr/src/app
WORKDIR /usr/src/app

RUN --mount=type=cache,id=pnpm,target=/pnpm/store pnpm install --frozen-lockfile

RUN pnpm run -r build

# >>> ai-task-obs:apm >>>
# 安装 APM 依赖（opentelemetry）
RUN cd /usr/src/app && pnpm add @opentelemetry/sdk-node @opentelemetry/exporter-trace-otlp-grpc @opentelemetry/auto-instrumentations-node @opentelemetry/resources
# <<< ai-task-obs:apm <<<

RUN pnpm deploy --filter=server --prod /app
RUN pnpm deploy --filter=server --prod /app-sqlite

RUN cd /app && pnpm exec prisma generate

RUN cd /app-sqlite && \
    rm -rf ./prisma && \
    mv prisma-sqlite prisma && \
    pnpm exec prisma generate

FROM base AS app-sqlite
COPY --from=build /app-sqlite /app

# >>> ai-task-obs:apm >>>
# 复制 APM 依赖到运行时
COPY --from=build /usr/src/app/node_modules/@opentelemetry /app/node_modules/@opentelemetry
# <<< ai-task-obs:apm <<<

WORKDIR /app

EXPOSE 8080

ENV NODE_ENV=production
ENV HOST="0.0.0.0"
ENV SERVER_ORIGIN_URL=""
ENV MAX_REQUEST_PER_MINUTE=60
ENV AUTH_CODE=""
ENV DATABASE_URL="file:../data/wewe-rss.db"
ENV DATABASE_TYPE="sqlite"
# ai-task-obs: 配置路径
ENV APP_CONFIG_PATH=/config/config.toml

RUN chmod +x ./docker-bootstrap.sh

CMD ["./docker-bootstrap.sh"]


FROM base AS app
COPY --from=build /app /app

# >>> ai-task-obs:apm >>>
# 复制 APM 依赖到运行时
COPY --from=build /usr/src/app/node_modules/@opentelemetry /app/node_modules/@opentelemetry
# <<< ai-task-obs:apm <<<

WORKDIR /app

EXPOSE 8080

ENV NODE_ENV=production
ENV HOST="0.0.0.0"
ENV SERVER_ORIGIN_URL=""
ENV MAX_REQUEST_PER_MINUTE=60
ENV AUTH_CODE=""
ENV DATABASE_URL=""
# ai-task-obs: 配置路径
ENV APP_CONFIG_PATH=/config/config.toml

RUN chmod +x ./docker-bootstrap.sh

CMD ["./docker-bootstrap.sh"]