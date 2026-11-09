# syntax=docker/dockerfile:1.7
# Kalla-Lai Flutter web image: build the release bundle, serve it with nginx,
# and proxy same-origin /v1 traffic to the API service.
#
# Build from the repository root:
#   docker build -t kalla-lai-web .
#
# KALLALAI_API_URL defaults to an empty string so the browser calls /v1 on the
# same origin. Set it only when the API is served from a different origin.

FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app

ARG KALLALAI_API_URL=""

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

RUN flutter build web --release --no-web-resources-cdn \
      --dart-define=KALLALAI_API_URL="${KALLALAI_API_URL}"

FROM nginxinc/nginx-unprivileged:1.27-alpine AS runtime

COPY deploy/nginx/default.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 8080
