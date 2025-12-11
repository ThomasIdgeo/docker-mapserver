# MapServer with PHP and Apache
# Multi-stage build for optimized image size

# ============================================================================
# STAGE 1: Builder - Compilation des dépendances
# ============================================================================
FROM debian:trixie AS builder
LABEL maintainer="Thomas Michel <thomas.michel@idgeo.fr>"

ENV HOME=/root
ENV GDAL_VERSION=3.12.0
ENV GEOS_VERSION=3.14.1
ENV PROJ_VERSION=9.7.0
ENV MAPSERVER_VERSION=branch-8-4

# Installation des dépendances de build et runtime
RUN apt-get update && \
	apt-get install -y \
		apache2 \
		bzip2 \
		build-essential \
		cmake \
		curl \
		git \
		libfreetype6-dev \
		libpng-dev \
		libjpeg62-turbo-dev \
		libcurl4-gnutls-dev \
		libxml2-dev \
		libcairo2-dev \
		libgif-dev \
		libpq-dev \
		libtiff5-dev \
		libxslt1-dev \
		libfcgi-dev \
		libodbc2 \
		swig \
		sqlite3 \
		tar \
		unzip \
		vim \
		wget \
		libcurl4 \
		zlib1g-dev \
		python3 \
		python3-pip \
		python3-dev \
		python3-setuptools \
		python3-wheel \
		libsqlite3-dev \
		libapache2-mod-fcgid \
		php \
		php-cli \
		php-fpm \
		php-curl \
		php-gd \
		php-xml \
		php-mbstring \
		php-zip \
		php-pgsql \
		libapache2-mod-php

# Install GEOS
RUN cd /root && \
	wget http://download.osgeo.org/geos/geos-$GEOS_VERSION.tar.bz2 && \
	tar -xjf geos-$GEOS_VERSION.tar.bz2 && \
	cd geos-$GEOS_VERSION && \
	./configure --prefix=/usr/local && \
	make -j$(nproc) && \
	make install && \
	ldconfig

# Install Proj
RUN cd /root && \
	wget http://download.osgeo.org/proj/proj-$PROJ_VERSION.tar.gz && \
	tar -xzf proj-$PROJ_VERSION.tar.gz && \
	cd proj-$PROJ_VERSION && \
	mkdir build && \
	cd build && \
	cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local && \
	cmake --build . -j$(nproc) && \
	cmake --build . --target install && \
	ldconfig

# Install GDAL
RUN cd /root && \
	wget http://download.osgeo.org/gdal/$GDAL_VERSION/gdal-$GDAL_VERSION.tar.gz && \
	tar -zxf gdal-$GDAL_VERSION.tar.gz && \
	cd gdal-$GDAL_VERSION && \
	mkdir build && \
	cd build && \
	cmake .. \
		-DCMAKE_INSTALL_PREFIX=/usr/local \
		-DBUILD_PYTHON_BINDINGS=OFF && \
	cmake --build . -j$(nproc) && \
	cmake --build . --target install && \
	ldconfig

# Install MapServer
RUN cd /root && \
	git clone https://github.com/mapserver/mapserver.git && \
	cd /root/mapserver && \
	git checkout ${MAPSERVER_VERSION} && \
	mkdir build && \
	cd build && \
	cmake .. \
		-DCMAKE_INSTALL_PREFIX=/usr/local \
		-DCMAKE_PREFIX_PATH=/usr/local \
		-DWITH_THREAD_SAFETY=ON \
		-DWITH_PROJ=ON \
		-DWITH_GDAL=ON \
		-DWITH_OGR=ON \
		-DWITH_GEOS=ON \
		-DWITH_CURL=ON \
		-DWITH_CLIENT_WMS=ON \
		-DWITH_CLIENT_WFS=ON \
		-DWITH_WMS=ON \
		-DWITH_WFS=ON \
		-DWITH_WCS=ON \
		-DWITH_SOS=OFF \
		-DWITH_KML=ON \
		-DWITH_FCGI=ON \
		-DWITH_CAIRO=ON \
		-DWITH_POSTGIS=ON \
		-DWITH_PHPNG=OFF \
		-DWITH_PYTHON=OFF \
		-DWITH_SVGCAIRO=OFF \
		-DWITH_XMLMAPFILE=OFF \
		-DWITH_EXEMPI=OFF \
		-DWITH_FRIBIDI=OFF \
		-DWITH_HARFBUZZ=OFF \
		-DWITH_PROTOBUFC=OFF \
		-DWITH_APACHE_MODULE=OFF && \
	make -j$(nproc) && \
	make install && \
	ldconfig

# Créer le lien symbolique pour CGI
RUN mkdir -p /usr/lib/cgi-bin && \
	ln -sf /usr/local/bin/mapserv /usr/lib/cgi-bin/mapserv

# ============================================================================
# STAGE 2: Image finale - Runtime optimisé
# ============================================================================
FROM debian:trixie

LABEL maintainer="Thomas Michel <thomas.michel@idgeo.fr>"

# Installation des dépendances runtime uniquement (pas de build tools)
RUN apt-get update && \
	apt-get install -y \
		apache2 \
		curl \
		libfreetype6 \
		libpng16-16 \
		libjpeg62-turbo \
		libcurl4 \
		libxml2 \
		libcairo2 \
		libgif7 \
		libpq5 \
		libtiff6 \
		libxslt1.1 \
		libfcgi0ldbl \
		libodbc2 \
		sqlite3 \
		libsqlite3-0 \
		zlib1g \
		libgeos-c1t64 \
		vim \
		nano \
		wget \
		libapache2-mod-fcgid \
		php \
		php-cli \
		php-fpm \
		php-curl \
		php-gd \
		php-xml \
		php-mbstring \
		php-zip \
		php-pgsql \
		libapache2-mod-php && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

# Copier les binaires et bibliothèques compilés depuis le builder
COPY --from=builder /usr/local /usr/local
COPY --from=builder /usr/lib/cgi-bin /usr/lib/cgi-bin

# Mettre à jour le cache des bibliothèques partagées
RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/local.conf && \
	ldconfig

# Activer les modules Apache nécessaires
RUN a2enmod cgi fcgid rewrite headers expires dir env setenvif && \
	PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || echo "8.3") && \
	a2enmod php${PHP_VERSION} 2>/dev/null || echo "PHP module already enabled"

# Configuration PHP
RUN PHP_VERSION=$(php -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;' 2>/dev/null || echo "8.3") && \
	PHP_INI_DIR="/etc/php/${PHP_VERSION}" && \
	if [ -d "$PHP_INI_DIR" ]; then \
		echo "date.timezone = Europe/Paris" >> ${PHP_INI_DIR}/apache2/php.ini 2>/dev/null || true; \
		echo "date.timezone = Europe/Paris" >> ${PHP_INI_DIR}/cli/php.ini 2>/dev/null || true; \
		echo "memory_limit = 256M" >> ${PHP_INI_DIR}/apache2/php.ini 2>/dev/null || true; \
		echo "upload_max_filesize = 50M" >> ${PHP_INI_DIR}/apache2/php.ini 2>/dev/null || true; \
		echo "post_max_size = 50M" >> ${PHP_INI_DIR}/apache2/php.ini 2>/dev/null || true; \
	fi

# Variables d'environnement Apache
ENV APACHE_RUN_USER=www-data \
	APACHE_RUN_GROUP=www-data \
	APACHE_LOG_DIR=/var/log/apache2 \
	APACHE_PID_FILE=/var/run/apache2/apache2.pid \
	APACHE_RUN_DIR=/var/run/apache2 \
	APACHE_LOCK_DIR=/var/lock/apache2 \
	APACHE_SERVERADMIN=admin@localhost \
	APACHE_SERVERNAME=localhost \
	APACHE_SERVERALIAS=docker.localhost \
	APACHE_DOCUMENTROOT=/var/www/html

# Créer les répertoires nécessaires
RUN mkdir -p /tmp/ms_tmp && \
	chmod 777 /tmp/ms_tmp && \
	mkdir -p /var/www/html && \
	mkdir -p /etc/mapserver && \
	mkdir -p /var/mapserver/data && \
	mkdir -p /var/log/apache2 && \
	mkdir -p /var/maps && \
	mkdir -p ${APACHE_RUN_DIR} && \
	mkdir -p ${APACHE_LOCK_DIR}

# Permissions
RUN chown -R www-data:www-data /var/www/html /tmp/ms_tmp

# Variables d'environnement MapServer
ENV MS_ERRORFILE=/tmp/ms_tmp/ms_error.log \
	MS_DEBUGLEVEL=0 \
	PROJ_LIB=/usr/local/share/proj

# Variables de locale
ENV LANG=fr_FR.UTF-8 \
	LC_ALL=fr_FR.UTF-8 \
	LANGUAGE=fr_FR:fr \
	TZ=Europe/Paris

# Installation des locales
RUN apt-get update && \
	apt-get install -y locales && \
	sed -i '/fr_FR.UTF-8/s/^# //g' /etc/locale.gen && \
	locale-gen fr_FR.UTF-8 && \
	update-locale LANG=fr_FR.UTF-8 LC_ALL=fr_FR.UTF-8 && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

# Copier les fichiers de configuration
COPY ./apache/default.conf /etc/apache2/sites-available/000-default.conf
COPY ./apache/default.conf /etc/apache2/conf-available/mapserver.conf

# Activer la configuration
RUN a2ensite 000-default && \
	a2enconf mapserver

# Créer un fichier de test
RUN echo '<?php phpinfo(); ?>' > /var/www/html/phpinfo.php && \
	echo '<html><body><h1>MapServer + PHP OK</h1></body></html>' > /var/www/html/index.html && \
	chown www-data:www-data /var/www/html/*

# Créer un script de démarrage
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
# Afficher les versions\n\
echo "================================="\n\
echo "MapServer version:"\n\
/usr/local/bin/mapserv -v\n\
echo ""\n\
echo "PHP version:"\n\
php -v\n\
echo ""\n\
echo "GDAL version:"\n\
gdalinfo --version\n\
echo "================================="\n\
\n\
# Créer les répertoires si nécessaire\n\
mkdir -p ${APACHE_RUN_DIR} ${APACHE_LOCK_DIR}\n\
\n\
# Démarrer Apache\n\
exec apache2ctl -D FOREGROUND' > /start.sh && \
	chmod +x /start.sh

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
	CMD curl -f http://localhost/ || exit 1

CMD ["/start.sh"]