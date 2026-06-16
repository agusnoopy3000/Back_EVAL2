# ---------- Etapa 1: instalación de dependencias ----------
FROM node:20-alpine AS deps

WORKDIR /app

# Copia solo los manifiestos para aprovechar la cache de capas
COPY package*.json ./

# Instala únicamente dependencias de producción
RUN npm install --omit=dev --no-audit --no-fund

# ---------- Etapa 2: imagen final minimalista ----------
FROM node:20-alpine AS runtime

# Herramienta mínima para el healthcheck
RUN apk add --no-cache wget

ENV NODE_ENV=production \
    PORT=3000

WORKDIR /app

# Copia las dependencias ya resueltas y el código fuente
COPY --from=deps /app/node_modules ./node_modules
COPY --chown=node:node . .

# --- Mínimo privilegio: usa el usuario 'node' (uid 1000) incluido en la imagen ---
USER node

# Expone solo el puerto del API
EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
    CMD wget -qO- http://localhost:${PORT:-3000}/ >/dev/null 2>&1 || exit 1

CMD ["node", "server.js"]
