# syntax=docker/dockerfile:1.7
# Kalla-Lai API image.
#
# Build from the repository root:
#   docker build -f server/Dockerfile -t kalla-lai-api ./server

FROM node:22-bookworm-slim AS build
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund

COPY tsconfig.json ./
COPY src ./src
COPY scripts ./scripts
RUN npm run build \
 && npm prune --omit=dev

FROM node:22-bookworm-slim AS runtime

ENV NODE_ENV=production \
    PORT=8080

# Run as an unprivileged, fixed-UID user so Kubernetes runAsNonRoot works.
RUN groupadd --system --gid 10001 kalla \
 && useradd --system --uid 10001 --gid kalla --home-dir /app --shell /usr/sbin/nologin kalla

WORKDIR /app

COPY --from=build --chown=10001:10001 /app/package.json ./
COPY --from=build --chown=10001:10001 /app/node_modules ./node_modules
COPY --from=build --chown=10001:10001 /app/dist ./dist
COPY --from=build --chown=10001:10001 /app/assets ./assets
# tsc does not copy .sql files; the migrator resolves them next to dist/db.
COPY --from=build --chown=10001:10001 /app/src/db/migrations ./dist/db/migrations

USER 10001:10001
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
  CMD ["node", "-e", "fetch('http://127.0.0.1:'+(process.env.PORT||8080)+'/healthz').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"]

CMD ["node", "dist/index.js"]
