# docker-mapserver from master

Mise à jour 07/2025, adaptation du dockerfile contexte cmake.

<img src="https://github.com/ThomasIdgeo/svg_ressources_idgeo/blob/main/icons_png/MapServer_logo.png?raw=true" width="80">

MapServer is build from Github source on the top of a Debian:latest base.

MapServer is build with fcgi support.

Port 80 is open and MapServer is located at host/cgi-bin/mapserv.fcgi

There is a rewrite rule making /maps/map_name points to /cgi-bin/mapserv.fcgi?map=/var/maps/map_name.map

For easy mapfile edition, run the container with -v /some/place/on/your/host:/var/maps and put your own mapfile in /some/place/on/your/host, making the mapfiles available for the container through the volume sharing.


## Prérequis

Il faut jongler avec les deux docs suivantes.

- Prérequis cmake [INSTALL.CMAKE](https://github.com/MapServer/MapServer/blob/main/INSTALL.CMAKE)

Depuis mon wsl, `sudo apt install cmake` en version 3.25.1 (07/2025). Cmake étant opensource on peut bien entendu recompiler depuis les sources. Pour Mapserver, il faut au minimum une version >3.

Gestion des dépendances dans le dokerfile. A partir de la ligne 11 et de la ligne 76 (option mapserver). J'ai ajouté le support fribidi et jharfbuzz (écriture droite à gauche), php pour mapscript et xmlmapfile support (+ dependances libxslt)

- [Compilation pour Linux](https://mapserver.org/installation/unix.html)

**Il faut GCC > 4.8**. Rappel installation GCC et bibliothèques de développement.

```bash
sudo apt update && sudo apt upgrade -y
```

```bash
sudo apt install gcc -y
```

```bash
sudo apt install build-essential -y
```

**Dépendances**

- GDAL 3.11.3 [https://gdal.org/en/stable/](https://gdal.org/en/stable/)
- PROJ 9.6.2 [https://proj.org/en/stable/news.html](https://proj.org/en/stable/news.html)
- GEOS 3.13.1 [https://libgeos.org/usage/download/](https://libgeos.org/usage/download/)

Vérification des librairies et des versions présentes dans le *repo apt*, semble correct.

## Compilation

Depuis le dossier concerné.

La compilation : le dockerfile est exécuté. 

Toutes les dépedances sont installées dans l'image basée sur Debian 12 bookwrom, puis GEOS, PROJ, GDAL et enfin Mapserver sont compilés depuis les sources. 

Ajout du tag 8.4. 

```bash
docker build -t thomasidgeo/mapserver:8.4 .
```

Se connecter à dockerhub

```bash
docker login
```

Pousser l'image sur le repo.

```bash
docker push thomasidgeo/mapserver:8.4
```

## Usage

Récupérer le zip, dézipper à l'endroit de votre choix. Personnaliser le docker-compose.yml avant de le lancer.

-------
Note de versions:
-------
- Apache 2.4
- PHP 8.2
- Mapserver 8.4
- GDAL 3.12.0
- GEOS 3.14.1
- PROJ 9.7.0