# MapServer from git master
# ~

# Etape 1 : compilation des dépendances
FROM debian:trixie AS builder
LABEL maintainer="Thomas Michel <thomas.michel@idgeo.fr>"

ENV HOME=/root
ENV GDAL_VERSION=3.12.0
ENV GEOS_VERSION=3.14.1
ENV PROJ_VERSION=9.7.0
ENV MAPSERVER_VERSION=branch-8-4
RUN apt-get update && \
	apt-get install -y apache2 \
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

RUN apt-get install -y libapache2-mod-fcgid libfcgi-dev sqlite3 libsqlite3-dev

# Install GEOS
RUN cd /root && \
	wget http://download.osgeo.org/geos/geos-$GEOS_VERSION.tar.bz2 && \
	tar -xjf geos-$GEOS_VERSION.tar.bz2 && \
	cd geos-$GEOS_VERSION && \
	./configure --prefix=/usr && \
	make && \
	make install && \
	make clean && \
	/sbin/ldconfig

# Install Proj7
RUN cd /root && \
    apt-get install -y libsqlite3-dev && \
	wget http://download.osgeo.org/proj/proj-$PROJ_VERSION.tar.gz && \
	tar -xzf proj-$PROJ_VERSION.tar.gz && \
	cd proj-$PROJ_VERSION/test && \
	wget http://download.osgeo.org/proj/proj-datumgrid-latest.zip && \
	unzip proj-datumgrid-latest.zip && \
	cd .. && \
	mkdir build && \
	cd build && \
	cmake .. && \
	cmake --build . && \
	cmake --build . --target install && \
	/sbin/ldconfig

# Install GDAL
RUN cd /root && \
    wget http://download.osgeo.org/gdal/$GDAL_VERSION/gdal-$GDAL_VERSION.tar.gz  && \
    tar -zxf gdal-$GDAL_VERSION.tar.gz && \
    cd gdal-$GDAL_VERSION && \
    mkdir build && \
    cd build && \
    cmake .. -DBUILD_PYTHON_BINDINGS=OFF && \
    cmake --build . && \
    cmake --build . --target install && \
    /sbin/ldconfig
RUN echo "/usr/local/lib" >> /etc/ld.so.conf

# Install MapServer
RUN cd /root && git clone https://github.com/mapserver/mapserver.git \
	&& cd /root/mapserver \
	&& git checkout ${MAPSERVER_VERSION} \
	&& mkdir /root/mapserver/build \
    && cd /root/mapserver/build \
	&& apt-get install libodbc2 swig libapache2-mod-fcgid libfcgi-dev sqlite3 libsqlite3-dev -y \
	&& cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_PREFIX_PATH=/usr/local:/opt \
	-DWITH_THREAD_SAFETY=1 -DWITH_CURL=1 -DWITH_PHPNG=0 -DWITH_SVGCAIRO=0 \ 
	-DWITH_CLIENT_WMS=1 -DWITH_CLIENT_WFS=1 -DWITH_SOS=0 -DWITH_KML=1 \
	-DWITH_MSSQL2008=0 -DWITH_PYTHON=0 -DWITH_SVGCAIRO=0 -DWITH_XMLMAPFILE=0 -DWITH_FCGI=1 \ 
	-DWITH_EXEMPI=0 -DWITH_FRIBIDI=0 -DWITH_HARFBUZZ=0 -DWITH_PROTOBUFC=0 -DWITH_APACHE_MODULE=0 \
    && make \ 
    && make install \
    && /sbin/ldconfig

RUN a2enmod rewrite php

#RUN apt-get install -y libapache2-mod-fcgid libfcgi-dev sqlite3 libsqlite3-dev
RUN ln -s /usr/local/bin/mapserv /usr/lib/cgi-bin/mapserv

RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* /root/geos-* /root/proj-* /root/gdal-*

# Etape2 : Image finale
FROM debian:trixie

# Copie les fichiers nécessaires depuis l'étape précédente du build
COPY --from=builder /usr/local /usr/local
COPY --from=builder /opt /opt
COPY --from=builder /etc/apache2 /etc/apache2
COPY --from=builder /var/www /var/www

# Set Apache environment variables (can be changed on docker run with -e)
ENV APACHE_RUN_USER=www-data
ENV APACHE_RUN_GROUP=www-data
ENV APACHE_LOG_DIR=/var/log/apache2
ENV APACHE_PID_FILE=/var/run/apache2.pid
ENV APACHE_RUN_DIR=/var/run/apache2
ENV APACHE_LOCK_DIR=/var/lock/apache2
ENV APACHE_SERVERADMIN=admin@localhost
ENV APACHE_SERVERNAME=localhost
ENV APACHE_SERVERALIAS=docker.localhost
ENV APACHE_DOCUMENTROOT=/var/www/html


EXPOSE 80
# Add FCGI configuration
ADD ./apache/default.conf /etc/apache2/conf-enabled/
ADD ./apache/default.conf /etc/apache2/sites-enabled/
ADD ./test.html /var/www/
ADD ./start.sh /start.sh
RUN mkdir /var/maps
RUN chmod 0755 /start.sh
RUN chown www-data:www-data -R /var/www/
CMD ["bash", "start.sh"]