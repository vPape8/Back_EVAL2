# =============================================
# STAGE 1: Builder
# Instala TODAS las dependencias (incluye devDependencies)
# =============================================
FROM node:18-alpine AS builder

WORKDIR /app

# Copiar solo archivos de dependencias primero (mejor cache de capas)
COPY package*.json ./

# Instalar todas las dependencias (incluye nodemon para dev)
RUN npm ci --include=dev

# Copiar el código fuente
COPY . .

# =============================================
# STAGE 2: Production
# Imagen final liviana, solo dependencias de producción
# =============================================
FROM node:18-alpine AS production

# Instalar dumb-init para manejo correcto de señales (PID 1)
RUN apk add --no-cache dumb-init

# Crear usuario no root por seguridad (mínimo privilegio)
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copiar dependencias de producción desde builder
COPY --from=builder --chown=appuser:appgroup /app/node_modules ./node_modules

# Copiar código fuente
COPY --chown=appuser:appgroup package*.json ./
COPY --chown=appuser:appgroup server.js ./

# Eliminar devDependencies para reducir tamaño de imagen final
RUN npm prune --production

# Cambiar al usuario no root
USER appuser

# Puerto del servidor Express
EXPOSE 3000

# Variables de entorno por defecto
ENV NODE_ENV=production \
    PORT=3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD node -e "require('http').get('http://localhost:3000/api/usuarios', (r) => r.statusCode === 200 ? process.exit(0) : process.exit(1)).on('error', () => process.exit(1))"

# Usar dumb-init como entrypoint para manejo correcto de SIGTERM
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "server.js"]