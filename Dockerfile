# syntax=docker/dockerfile:1
# Super-slim static image for zero-zerogpt (React 18 SPA).
# Multi-stage: node:20-alpine builds (never shipped), chainguard/nginx serves.
# Final image ~15 MB compressed (vs ~26 MB on nginx:alpine).

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
# Chainguard (Wolfi-based) nginx: non-root, no shell, no package manager,
# minimal attack surface. Serves the same nginx.conf as the alpine variant.
FROM cgr.dev/chainguard/nginx
WORKDIR /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build .
EXPOSE 80
# No HEALTHCHECK: this image has no wget/curl/busybox to probe with.
# Diagnostics instead:
#   - `docker logs <ctr>`          -> nginx access/error logs (image CMD routes to stderr)
#   - `docker run --rm --entrypoint /usr/sbin/nginx <image> -T`  -> dump full config
# No explicit CMD: the image's default (entrypoint=/usr/sbin/nginx,
# CMD=[-c /etc/nginx/nginx.conf -e /dev/stderr -g "daemon off;"]) launches
# nginx in the foreground; it self-drops to its configured unprivileged user.
