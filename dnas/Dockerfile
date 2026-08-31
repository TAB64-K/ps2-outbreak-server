FROM debian:11


RUN apt-get update && apt-get install -y \
    sudo \
    make \
    gcc \
    dnsutils \
    unzip \
    php-fpm \
    mariadb-server \
    php7.4-mysql \
    libpcre3 \
    libpcre3-dev \
    libexpat1 \
    libexpat1-dev \
    libxml2 \
    libxml2-dev \
    libxslt1-dev \
    libxslt1.1 \
    wget \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*


COPY openssl-1.0.2u.tar.gz /tmp/openssl-1.0.2u.tar.gz


RUN cd /tmp && \
    tar xzvf openssl-1.0.2u.tar.gz && \
    cd openssl-1.0.2u && \
    ./config --prefix=/opt/openssl-1.0.2 \
    --openssldir=/etc/ssl \
    shared enable-weak-ssl-ciphers \
    enable-ssl3 enable-ssl3-method \
    enable-ssl2 \
    -Wl,-rpath=/opt/openssl-1.0.2/lib && \
    make depend && \
    make && \
    make install

RUN echo '/opt/openssl-1.0.2/lib' >> /etc/ld.so.conf.d/x86_64-linux-gnu.conf && \
    ldconfig

RUN cd /tmp && \
    wget https://archive.apache.org/dist/httpd/httpd-2.4.56.tar.gz && \
    wget https://archive.apache.org/dist/apr/apr-1.7.2.tar.gz && \
    wget https://archive.apache.org/dist/apr/apr-util-1.6.3.tar.gz

RUN cd /tmp && \
    tar xzvf httpd-2.4.56.tar.gz && \
    cd httpd-2.4.56/srclib/ && \
    tar xzvf /tmp/apr-1.7.2.tar.gz && \
    tar xzvf /tmp/apr-util-1.6.3.tar.gz && \
    ln -s apr-1.7.2 apr && \
    ln -s apr-util-1.6.3 apr-util && \
    cd /tmp/httpd-2.4.56 && \
    ./configure --prefix=/opt/apache \
    --with-included-apr \
    --with-ssl=/opt/openssl-1.0.2 \
    --enable-ssl \
    --enable-rewrite \
    --enable-proxy \
    --enable-proxy-fcgi && \
    make && \
    make install

RUN sed -i '/^export/i LD_LIBRARY_PATH="/opt/openssl-1.0.2/lib:$LD_LIBRARY_PATH"' \
    /opt/apache/bin/envvars

RUN sed -i 's/^User daemon/User www-data/' /opt/apache/conf/httpd.conf && \
    sed -i 's/^Group daemon/Group www-data/' /opt/apache/conf/httpd.conf

RUN sed -i 's/#LoadModule rewrite_module/LoadModule rewrite_module/' /opt/apache/conf/httpd.conf && \
    sed -i 's/#LoadModule proxy_module/LoadModule proxy_module/' /opt/apache/conf/httpd.conf && \
    sed -i 's/#LoadModule proxy_fcgi_module/LoadModule proxy_fcgi_module/' /opt/apache/conf/httpd.conf && \
    sed -i 's/#LoadModule ssl_module/LoadModule ssl_module/' /opt/apache/conf/httpd.conf

RUN mkdir -p /var/www
COPY ./DNASrep/etc/dnas/ /etc/dnas/
COPY ./DNASrep/www/dnas/ /var/www/dnas/
RUN chown -R 0:0 /etc/dnas && \
    chown -R www-data:www-data /var/www/dnas

RUN cat >> /opt/apache/conf/httpd.conf << 'APACHECONF'

<IfModule ssl_module>
        Listen *:443
        SSLEngine on
        SSLCipherSuite DHE:!DSS:!AES:!SEED:!CAMELLIA!TLSv1.2
        SSLCertificateFile /etc/dnas/cert-jp.pem
        SSLCertificateKeyFile /etc/dnas/cert-jp-key.pem
        SSLCertificateChainFile /etc/dnas/ca-cert.pem
        ServerName gate1.jp.dnas.playstation.org
        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/dnas
        <Directory />
                Options FollowSymLinks
                AllowOverride None
        </Directory>
        <Directory "/var/www/dnas">
                Options -Indexes
                Require all granted
        </Directory>
        RewriteEngine on
        RewriteRule ^(/.*)/v2\.5_i-connect$ $1/connect.php [PT]
        RewriteRule ^(/.*)/i-connect$ $1/connect.php [PT]
        RewriteRule ^(/.*)/v2\.5_d-connect$ $1/connect.php [PT]
        RewriteRule ^(/.*)/v2\.5_others$ $1/others.php [PT]
        RewriteRule ^(/.*)/others$ $1/others.php [PT]
        <FilesMatch "\.php$">
                SetHandler "proxy:unix:/var/run/php/php7.4-fpm.sock|fcgi://127.0.0.1"
        </FilesMatch>
        ErrorLog /opt/apache/logs/dnas_error.log
        LogLevel debug
        CustomLog /opt/apache/logs/dnas_access.log combined
        <FilesMatch "\.(cgi|shtml|phtml|php)$">
                SSLOptions +StdEnvVars
        </FilesMatch>
        <Directory /usr/lib/cgi-bin>
                SSLOptions +StdEnvVars
        </Directory>
        BrowserMatch "open sesame asdfjkl" \
        nokeepalive ssl-unclean-shutdown \
        downgrade-1.0 force-response-1.0
</IfModule>
APACHECONF

EXPOSE 80 443

CMD service php7.4-fpm start && \
    /opt/apache/bin/apachectl -k start -DFOREGROUND