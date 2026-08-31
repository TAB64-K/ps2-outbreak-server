#!/bin/bash
set -e

echo "==> Starting MariaDB..."
service mariadb start

# Wait for MariaDB to be ready
until mysqladmin ping --silent; do
    echo "    Waiting for MariaDB..."
    sleep 2
done

echo "==> Setting up database..."
mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` DEFAULT CHARACTER SET latin1 COLLATE latin1_swedish_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
EOF

# Import schema only if tables don't exist yet
TABLE_COUNT=$(mysql -u root -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${DB_NAME}';" -s -N)
if [ "$TABLE_COUNT" -eq "0" ]; then
    echo "==> Importing database schema..."
    mysql -u root "${DB_NAME}" < /docker-entrypoint-initdb/bioserver.sql
    echo "    Schema imported."
else
    echo "    Database already initialized, skipping."
fi

echo "==> Starting Apache..."
service apache2 start

echo "==> Starting Biohazard Outbreak 2 Server..."
exec java -jar /opt/bioserver2/BiohazardOutbreak2Server.jar
