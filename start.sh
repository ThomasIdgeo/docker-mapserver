#!/bin/bash
# Start APACHE WEBSERVER
/usr/sbin/apache2 -D FOREGROUND

# Ajout du dossier /opt/bin dans le path
export PATH="/opt/bin:$PATH"

# Lien symbolique vers menu traditionnel
ln -s /usr/local/bin/mapserv /usr/lib/cgi-bin/mapserv
