# ============================================================
# Biohazard Outbreak File #1 - Private Server
# Multi-stage build: compile Java → runtime image
# ============================================================

# ── Stage 1: Build JAR ───────────────────────────────────────
FROM debian:bullseye-slim AS builder

RUN apt-get update && apt-get install -y \
    openjdk-11-jdk-headless \
    wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

COPY Bioserver1-master/bioserver/ ./bioserver/

# MySQL connector 5.1.49 (required - uses com.mysql.jdbc old API)
RUN wget -q https://repo1.maven.org/maven2/mysql/mysql-connector-java/5.1.49/mysql-connector-java-5.1.49.jar \
         -O mysql-connector.jar

# Compile all .java files
RUN mkdir -p out && \
    find bioserver/ -name "*.java" > sources.txt && \
    javac -cp mysql-connector.jar \
          -d out \
          @sources.txt

# Package into JAR
RUN echo "Main-Class: bioserver.ServerMain" > manifest.txt && \
    echo "Class-Path: mysql-connector.jar" >> manifest.txt && \
    echo "" >> manifest.txt && \
    jar cfm BiohazardOutbreak1Server.jar manifest.txt -C out .


# ── Stage 2: Runtime Image ───────────────────────────────────
FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive \
    DB_NAME=bioserver \
    DB_USER=bioserver \
    DB_PASSWORD=changeme \
    GS_IP=0.0.0.0

RUN apt-get update && apt-get install -y \
    openjdk-11-jre-headless \
    mariadb-server \
    apache2 \
    php \
    php-mysql \
    libapache2-mod-php \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/bioserver1

# Copy compiled JAR + connector from builder
COPY --from=builder /build/BiohazardOutbreak1Server.jar ./
COPY --from=builder /build/mysql-connector.jar ./

# Copy config + database schema
COPY Bioserver1-master/bioserver/config.properties ./
COPY Bioserver1-master/database/bioserver.sql /docker-entrypoint-initdb/bioserver.sql

# Copy www files
COPY Bioserver1-master/www/ /var/www/html/bhof1/
COPY Bioserver1-master/patch/patch_101.raw /opt/bioserver1/patch.raw

# Configure Apache on port 8081 (8080 محجوزة لـ bioserver2)
RUN a2enmod rewrite && \
    chown -R www-data:www-data /var/www/html/bhof1 && \
    sed -i 's/Listen 80/Listen 8081/' /etc/apache2/ports.conf && \
    sed -i 's/<VirtualHost \*:80>/<VirtualHost *:8081>/' /etc/apache2/sites-enabled/000-default.conf

# ── Ports ────────────────────────────────────────────────────
EXPOSE 8081 8300 8690
# 8081 = Apache/PHP
# 8300 = LOBBYPORT
# 8690 = GAMEPORT

COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]