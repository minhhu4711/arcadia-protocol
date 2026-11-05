# Static build of the ARCADIA web app served by nginx.
FROM oven/bun:1 AS build
WORKDIR /app
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile
COPY . .
ARG VITE_ARCADIA_FACTORY
ARG VITE_ARCADIA_VAULT
ARG VITE_ARCADIA_DEPLOY_BLOCK
ENV VITE_ARCADIA_FACTORY=$VITE_ARCADIA_FACTORY \
    VITE_ARCADIA_VAULT=$VITE_ARCADIA_VAULT \
    VITE_ARCADIA_DEPLOY_BLOCK=$VITE_ARCADIA_DEPLOY_BLOCK
RUN bunx vite build

FROM nginx:1.27-alpine
COPY --from=build /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
