# Stage 1: Build
FROM node:20-alpine AS builder

WORKDIR /app

# Build-time argument for the backend API URL
# Next.js inlines NEXT_PUBLIC_* variables at build time
ARG NEXT_PUBLIC_API_BASE_URL=https://zests-backend-27pbknzl5a-el.a.run.app/api/v1
ENV NEXT_PUBLIC_API_BASE_URL=$NEXT_PUBLIC_API_BASE_URL

# Install dependencies first (for caching)
COPY package.json ./
RUN npm install

# Copy source and build
COPY . .
RUN npm run build

# Stage 2: Run
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=8080

# Copy necessary files from builder
COPY --from=builder /app/next.config.mjs ./
COPY --from=builder /app/package.json ./
COPY --from=builder /app/.next ./.next
# COPY --from=builder /app/public ./public
COPY --from=builder /app/node_modules ./node_modules

EXPOSE 8080

CMD ["npm", "run", "start"]
