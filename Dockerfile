# ─────────────────────────────────────────────
#  Stage 1: Install ALL deps (dev + prod)
# ─────────────────────────────────────────────
FROM node:20-alpine AS deps

WORKDIR /app

RUN apk add --no-cache libc6-compat python3 make g++

COPY package*.json ./
RUN npm ci --prefer-offline


# ─────────────────────────────────────────────
#  Stage 2: Build TypeScript
# ─────────────────────────────────────────────
FROM node:20-alpine AS builder

WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY . .

RUN npm run build

# Debug: show what was compiled so you know the real entry path
RUN echo "=== Build output ===" && find dist -name "*.js" | head -20


# ─────────────────────────────────────────────
#  Stage 3: Production image
# ─────────────────────────────────────────────
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=10000

# Non-root user for security
RUN addgroup --system --gid 1001 nodejs \
 && adduser  --system --uid 1001 tatakai

# Install only production node_modules
COPY package*.json ./
RUN npm ci --omit=dev --prefer-offline && npm cache clean --force

# Copy compiled output
COPY --from=builder --chown=tatakai:nodejs /app/dist ./dist

# ⚠️  IMPORTANT: server.ts reads src/docs at runtime via fs.readFileSync
# These markdown files MUST exist in the container at the same relative path
COPY --from=builder --chown=tatakai:nodejs /app/src/docs ./src/docs

# Copy public assets (served as static files)
COPY --from=builder --chown=tatakai:nodejs /app/public ./public

# package.json is imported at runtime (pkgJson import in server.ts)
COPY --chown=tatakai:nodejs package.json ./

USER tatakai

EXPOSE 10000

# Healthcheck — matches the /health route that returns "daijoubu"
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
  CMD wget -qO- http://localhost:10000/health || exit 1

# Auto-detect entry point: tries dist/server.js then dist/src/server.js
CMD ["sh", "-c", "\
  if [ -f dist/server.js ]; then \
    exec node dist/server.js; \
  elif [ -f dist/src/server.js ]; then \
    exec node dist/src/server.js; \
  else \
    echo 'ERROR: Cannot find compiled entry point. Run docker build to see dist/ contents above.' && exit 1; \
  fi \
"]
