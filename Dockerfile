# syntax=docker/dockerfile:1
# Super-slim static image for zero-zerogpt (React 18 SPA).
# Multi-stage: node:20-alpine builds (never shipped), nginx:stable-alpine-slim serves.
# Final image ~8 MB compressed (was ~26 MB on nginx:alpine with source maps).
# The runtime image keeps a real shell (sh/busybox) + wget, so `docker exec`
# and the wget healthcheck both work for easy diagnostics.

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
# Don't ship source maps. They add ~13 MB (main.js.map alone) to the image and
# are a security footgun in a public image (they expose the full source).
# Pure env override — no package.json / source change, so the fork stays clean.
ENV GENERATE_SOURCEMAP=false
RUN npm run build

# ---- runtime stage ------------------------------------------------------
# Official slim alpine nginx: full nginx (gzip + SPA fallback via nginx.conf),
# plus /bin/sh, /bin/busybox and /usr/bin/wget for shell access + healthcheck.
FROM nginx:stable-alpine-slim
WORKDIR /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build .
EXPOSE 80
# wget IS present in this base, so the standard health probe works.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://127.0.0.1/ >/dev/null 2>&1 || exit 1
CMD ["nginx", "-g", "daemon off;"]
