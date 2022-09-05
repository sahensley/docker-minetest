FROM ghcr.io/linuxserver/baseimage-alpine:3.15

# set version label
ARG BUILD_DATE
ARG VERSION
ARG MINETEST_RELEASE
LABEL build_version="Linuxserver.io version:- ${VERSION} Build-date:- ${BUILD_DATE}"
LABEL maintainer="aptalca"

# environment variables
ENV HOME="/config" \
  MINETEST_SUBGAME_PATH="/config/.minetest/games"

# build variables
ARG LDFLAGS="-lintl"

RUN \
  echo "**** install build packages ****" && \
  apk add --no-cache --virtual=build-dependencies \
    bzip2-dev \
    cmake \
    curl-dev \
    doxygen \
    g++ \
    gcc \
    gettext-dev \
    git \
    gmp-dev \
    hiredis-dev \
    icu-dev \
    jq \
    leveldb-dev \
    libjpeg-turbo-dev \
    libogg-dev \
    libpng-dev \
    libressl-dev \
    libtool \
    libvorbis-dev \
    libxi-dev \
    luajit-dev \
    make \
    mesa-dev \
    ncurses-dev \
    openal-soft-dev \
    postgresql-dev \
    python3-dev \
    sqlite-dev \
    zstd-dev && \
  echo "**** install runtime packages ****" && \
  apk add --no-cache \
    curl \
    gmp \
    hiredis \
    leveldb \
    libgcc \
    libintl \
    libstdc++ \
    luajit \
    lua-socket \
    postgresql-libs \
    postgresql-client \
    sqlite \
    sqlite-libs \
    zstd \
    zstd-libs && \
  echo "**** compile spatialindex ****" && \
  git clone https://github.com/libspatialindex/libspatialindex /tmp/spatialindex && \
  cd /tmp/spatialindex && \
  cmake . \
    -DCMAKE_INSTALL_PREFIX=/usr && \
  make -j 2 && \
  make install && \
  echo "**** compile irrlicht ****" && \
  mkdir -p /tmp/irrlicht && \
  IRRLICHT_VER=$(curl -sX GET "https://api.github.com/repos/minetest/irrlicht/releases/latest" \
    | jq -r .tag_name) && \
  curl -o /tmp/irrlicht.tar.gz \
    -L "https://github.com/minetest/irrlicht/archive/${IRRLICHT_VER}.tar.gz" && \
  tar xf /tmp/irrlicht.tar.gz -C \
    /tmp/irrlicht --strip-components=1 && \
  cd /tmp/irrlicht && \
  cmake . && \
  make -j 2 && \
  make install && \
  echo "**** compile minetestserver ****" && \
  if [ -z ${MINETEST_RELEASE+x} ]; then \
    MINETEST_RELEASE=$(curl -sX GET "https://api.github.com/repos/minetest/minetest/releases" \
      | jq -r 'first(.[] | select(.tag_name | contains("android") | not)) | .tag_name'); \
  fi && \
  mkdir -p \
    /tmp/minetest && \
  curl -o \
    /tmp/minetest-src.tar.gz -L \
    "https://github.com/minetest/minetest/archive/${MINETEST_RELEASE}.tar.gz" && \
  tar xf \
  /tmp/minetest-src.tar.gz -C \
    /tmp/minetest --strip-components=1 && \
  cp /tmp/minetest/minetest.conf.example /defaults/minetest.conf && \
  cd /tmp/minetest && \
  cmake . \
    -DBUILD_CLIENT=0 \
    -DBUILD_SERVER=1 \
    -DCMAKE_INSTALL_PREFIX=/usr \
    -DCUSTOM_BINDIR=/usr/bin \
    -DCUSTOM_DOCDIR="/usr/share/doc/minetest" \
    -DCUSTOM_SHAREDIR="/usr/share/minetest" \
    -DENABLE_CURL=1 \
    -DENABLE_FREETYPE=1 \
    -DENABLE_GETTEXT=0 \
    -DENABLE_LEVELDB=1 \
    -DENABLE_LUAJIT=1 \
    -DENABLE_POSTGRESQL=1 \
    -DENABLE_REDIS=1 \
    -DENABLE_SOUND=0 \
    -DENABLE_SYSTEM_GMP=1 \
    -DRUN_IN_PLACE=0 && \
  make -j 2 && \
  make install && \
  echo "**** copy games to temporary folder ****" && \
  mkdir -p \
    /defaults/games && \
  cp -pr  /usr/share/minetest/games/* /defaults/games/ && \
  echo "**** split after 3rd dot if it exists in minetest tag variable ****" && \
  echo "**** so we fetch game version x.x.x etc ****" && \
  if [ $(echo "$MINETEST_RELEASE" | tr -cd '.' | wc -c) = 3 ]; then \
    MINETEST_RELEASE=${MINETEST_RELEASE%.*}; \
  fi && \
  echo "**** fetch additional game ****" && \
  mkdir -p \
    /defaults/games/minetest && \
  curl -o \
    /tmp/minetest-game.tar.gz -L \
    "https://github.com/minetest/minetest_game/archive/${MINETEST_RELEASE}.tar.gz" && \
  tar xf \
    /tmp/minetest-game.tar.gz -C \
    /defaults/games/minetest --strip-components=1 && \
  echo "**** cleanup ****" && \
  apk del --purge \
    build-dependencies && \
  rm -rf \
    /tmp/*

# add local files
COPY root /

# ports and volumes
EXPOSE 30000/udp
VOLUME /config/.minetest
