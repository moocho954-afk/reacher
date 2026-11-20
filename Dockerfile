# ReacheR API — standalone Bun server (zero npm dependencies).
FROM oven/bun:1.3-slim
WORKDIR /app
COPY server/package.json server/tsconfig.json ./
COPY server/src ./src
# SQLite data lives here. On Render, mount the persistent disk at /data
# (Starter plan and up) and set DATABASE_PATH=/data/reacher.db.
# On the Free plan there is no disk: data is ephemeral (see README).
RUN mkdir -p /data
ENV PORT=3000
ENV DATABASE_PATH=/data/reacher.db
EXPOSE 3000
CMD ["bun", "run", "src/server.ts"]
