#!/bin/bash

curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
mkdir -p /srv/zerotier

rm get-docker.sh
cat <<EOF > /srv/zerotier/docker-compose.yml
services:
  postgres:
    image: postgres:15.2-alpine
    container_name: ztnet-database
    restart: unless-stopped
    environment:
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: ztnet
    volumes:
      - postgres-data:/var/lib/postgresql/data

  zerotier:
    image: zyclonite/zerotier:1.14.2
    hostname: zerotier
    container_name: zerotier
    restart: unless-stopped
    volumes:
      - zerotier:/var/lib/zerotier-one
    cap_add:
      - NET_ADMIN
      - SYS_ADMIN
    devices:
      - /dev/net/tun:/dev/net/tun
    ports:
      - "9993:9993/udp"
    environment:
      - ZT_OVERRIDE_LOCAL_CONF=true
      - ZT_ALLOW_MANAGEMENT_FROM=172.31.255.0/29

  ztnet:
    image: sinamics/ztnet:latest
    container_name: ztnet
    working_dir: /app 
    volumes:
      - zerotier:/var/lib/zerotier-one
    restart: unless-stopped
    ports:
      - 3000:3000
    environment:
      POSTGRES_HOST: postgres
      POSTGRES_PORT: 5432
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: ztnet
      NEXTAUTH_URL: "http://localhost:3000"
      NEXTAUTH_SECRET: "random_secret"
      NEXTAUTH_URL_INTERNAL: "http://ztnet:3000"
    links:
      - postgres
    depends_on:
      - postgres
      - zerotier

volumes:
  zerotier:
  postgres-data:
  #caddy_data:

networks:
  default:
    name: zerotier
    driver: bridge
    ipam:
      driver: default
      config:
        - subnet: 172.31.255.0/29
EOF

docker compose -f /srv/zerotier/docker-compose.yml up -d
