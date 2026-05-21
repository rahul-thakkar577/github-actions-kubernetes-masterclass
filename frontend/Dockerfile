# Stage 1: Build assets
FROM node:22-alpine AS builder
WORKDIR /app
COPY . .
RUN mkdir -p /output && \
    cp index.html /output/ && \
    cp -r css js /output/

# Stage 2: Serve
FROM nginx:1.27-alpine
RUN rm -rf /usr/share/nginx/html/*
COPY --from=builder /output /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80