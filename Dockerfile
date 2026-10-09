# syntax=docker/dockerfile:1
# Super-slim static image for zero-zerogpt (React 18 SPA).
# Multi-stage: node:alpine builds, nginx:alpine serves. Final image ~6 MB + ~1 MB assets.

# ---- build stage --------------------------------------------------------
FROM node:20-alpine AS build
WORKDIR /app

# Install deps from lockfile first to maximise layer caching.
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund

# Copy the rest and build. CI=true turns warnings into errors for a clean break.
COPY . .
ENV CI=true
# Serve from the root of the container rather than the /zero-zerogpt/
# GitHub Pages path: PUBLIC_URL overrides the homepage base path.
ARG PUBLIC_URL=/
RUN npm run build

# ---- runtime stage ------------------------------------------------------
FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build /usr/share/nginx/html
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1/ >/dev/null 2>&1 || exit 1
CMD ["nginx", "-g", "daemon off;"]
