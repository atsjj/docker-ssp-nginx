FROM nginx:latest
MAINTAINER Steve Jabour <steve@jabour.me>

ENV GPG_KEYS 3D9A1B1AC72E5318
ENV SSP_VERSION 1.5.4.10265
ENV SSP_HOST localhost:9000
ENV SSP_URL https://summit.com/assets/slideshow-pro-director.tar.xz
ENV SSP_ASC_URL https://summit.com/assets/slideshow-pro-director.tar.xz.asc
ENV SSP_SHA256 1914a5b9986f909ee4d37d408580c585e9ae12d34b9d9eb6f588f94d97b66b04
ENV SSP_MD5 ffef04080ce91e501b23781db8c108a8

# install slideshow-pro-director and environment inside the container
COPY docker-ssp-source /usr/local/bin/

RUN set -xe; \
  \
  fetchDeps=' \
    wget \
    xz-utils \
  '; \
  apt-get update; \
  apt-get install -y --no-install-recommends $fetchDeps; \
  rm -rf /var/lib/apt/lists/*; \
  \
  cd /tmp; \
  \
  wget -O slideshow-pro-director.tar.xz "$SSP_URL"; \
  \
  if [ -n "$SSP_SHA256" ]; then \
    echo "$SSP_SHA256 *slideshow-pro-director.tar.xz" | sha256sum -c -; \
  fi; \
  if [ -n "$SSP_MD5" ]; then \
    echo "$SSP_MD5 *slideshow-pro-director.tar.xz" | md5sum -c -; \
  fi; \
  \
  export GNUPGHOME="$(mktemp -d)"; \
  \
  for key in $GPG_KEYS; do \
    gpg --keyserver ha.pool.sks-keyservers.net --recv-keys "$key"; \
  done; \
  \
  if [ -n "$SSP_ASC_URL" ]; then \
    wget -O slideshow-pro-director.tar.xz.asc "$SSP_ASC_URL"; \
    gpg --batch --verify slideshow-pro-director.tar.xz.asc slideshow-pro-director.tar.xz; \
  fi; \
  \
  rm -r "$GNUPGHOME"; \
  \
  docker-ssp-source extract; \
  cd /var/www; \
  chown -R www-data:www-data slideshow-pro-director; \
  \
  apt-get purge -y --auto-remove $fetchDeps

COPY docker-nginx /usr/local/bin/

WORKDIR /var/www/slideshow-pro-director

RUN set -ex \
  && cd /etc/nginx \
  && { \
    echo 'server {'; \
    echo '  listen 80;'; \
    echo '  listen [::]:80 default ipv6only=on;'; \
    echo '  server_name _;'; \
    echo; \
    echo '  root   /var/www/slideshow-pro-director;'; \
    echo '  index  index.php;'; \
    echo; \
    echo '  error_log /dev/stdout info;'; \
    echo '  access_log /dev/stdout;'; \
    echo; \
    echo '  location / {'; \
    echo '    try_files $uri $uri/ /index.php?$args;'; \
    echo '  }'; \
    echo; \
    echo '  location ~ \.php$ {'; \
    echo '    client_max_body_size 1024M;'; \
    echo; \
    echo '    try_files $uri =404;'; \
    echo; \
    echo '    include         fastcgi_params;'; \
    echo; \
    echo '    fastcgi_pass    fastcgi-server;'; \
    echo '    fastcgi_index   index.php;'; \
    echo '    fastcgi_param   SCRIPT_FILENAME $document_root$fastcgi_script_name;'; \
    echo '  }'; \
    echo '}'; \
  } | tee conf.d/default.conf \
  && { \
    echo 'upstream fastcgi-server {'; \
    echo '  server ${SSP_HOST};'; \
    echo '}'; \
  } | tee fastcgi-server.conf.template

# clean-up after install
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# nginx on port 80 and 443
EXPOSE 80 443

# run docker-nginx on container start
CMD ["docker-nginx"]
