#!/bin/bash
set -e

echo "==> Starting MariaDB..."
service mariadb start

until mysqladmin ping --silent; do
    echo "    Waiting for MariaDB..."
    sleep 2
done

echo "==> Setting up database..."
mysql -u root <<SQLEOF
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` DEFAULT CHARACTER SET latin1 COLLATE latin1_swedish_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
ALTER USER '${DB_USER}'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('${DB_PASSWORD}');
ALTER USER '${DB_USER}'@'%' IDENTIFIED VIA mysql_native_password USING PASSWORD('${DB_PASSWORD}');
FLUSH PRIVILEGES;
SQLEOF

TABLE_COUNT=$(mysql -u root -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${DB_NAME}';" -s -N)
if [ "$TABLE_COUNT" -eq "0" ]; then
    echo "==> Importing database schema..."
    mysql -u root "${DB_NAME}" < /docker-entrypoint-initdb/bioserver.sql
    echo "    Schema imported."
else
    echo "    Database already initialized, skipping."
fi

# Fix MariaDB to listen on all interfaces
sed -i 's/bind-address.*=.*127.0.0.1/bind-address = 0.0.0.0/' /etc/mysql/mariadb.conf.d/50-server.cnf
service mariadb restart

sleep 3
until mysqladmin ping --silent; do
    echo "    Waiting for MariaDB to restart..."
    sleep 2
done

echo "==> Starting Apache..."
service apache2 start

echo "==> Starting Biohazard Outbreak 1 Server..."
exec java -jar /opt/bioserver1/BiohazardOutbreak1Server.jar