# ============================================================
# Biohazard Outbreak File #2 - Private Server
# Multi-stage build: compile Java → runtime image
# ============================================================

# ── Stage 1: Build JAR ───────────────────────────────────────
FROM debian:bullseye-slim AS builder

RUN apt-get update && apt-get install -y \
    openjdk-11-jdk-headless \
    wget \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Copy all Java source files
COPY Bioserver2-master/bioserver/ ./bioserver/

# Download MySQL connector 5.1.49 (required - Database.java uses com.mysql.jdbc old API)
RUN wget -q https://repo1.maven.org/maven2/mysql/mysql-connector-java/5.1.49/mysql-connector-java-5.1.49.jar \
         -O mysql-connector.jar

# Compile all .java files
RUN mkdir -p out && \
    find bioserver/ -name "*.java" > sources.txt && \
    javac -cp mysql-connector.jar \
          -d out \
          @sources.txt

# Package into JAR with manifest
RUN echo "Main-Class: bioserver.ServerMain" > manifest.txt && \
    echo "Class-Path: mysql-connector.jar" >> manifest.txt && \
    echo "" >> manifest.txt && \
    jar cfm BiohazardOutbreak2Server.jar manifest.txt -C out .


# ── Stage 2: Runtime Image ───────────────────────────────────
FROM debian:bullseye-slim

ENV DEBIAN_FRONTEND=noninteractive \
    DB_NAME=bioserver2 \
    DB_USER=bioserver \
    DB_PASSWORD=changeme \
    GS_IP=0.0.0.0

# Install runtime dependencies only (no JDK)
RUN apt-get update && apt-get install -y \
    openjdk-11-jre-headless \
    mariadb-server \
    apache2 \
    php \
    php-mysql \
    libapache2-mod-php \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/bioserver2

# Copy compiled JAR + mysql connector from builder
COPY --from=builder /build/BiohazardOutbreak2Server.jar ./
COPY --from=builder /build/mysql-connector.jar ./

# Copy config + database schema + www files
COPY Bioserver2-master/bioserver/config.properties ./
COPY Bioserver2-master/database/bioserver.sql /docker-entrypoint-initdb/bioserver.sql
COPY Bioserver2-master/www/ /var/www/html/bhof2/

# Configure Apache on port 8080 (80/443 reserved for DNAS container)
RUN a2enmod rewrite && \
    chown -R www-data:www-data /var/www/html/bhof2 && \
    sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf && \
    sed -i 's/<VirtualHost \*:80>/<VirtualHost *:8080>/' /etc/apache2/sites-enabled/000-default.conf

# ── Ports ────────────────────────────────────────────────────
EXPOSE 8080 8200 8590
# 8080 = Apache/PHP  (80/443 محجوزة لـ DNAS)
# 8200 = LOBBYPORT
# 8590 = GAMEPORT

# ── Entrypoint ───────────────────────────────────────────────
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]