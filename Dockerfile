FROM flant/shell-operator:v1.6.1

RUN export REDIS_VERSION="7.4.1" && \
    export REDIS_DOWNLOAD_URL="http://download.redis.io/releases/redis-${REDIS_VERSION}.tar.gz" && \
    apk update && \
    apk upgrade && \
    apk add --update --no-cache --virtual build-deps gcc make linux-headers musl-dev tar openssl-dev pkgconfig && \
    wget -O redis.tar.gz "$REDIS_DOWNLOAD_URL" && \
    mkdir -p /usr/src/redis && \
    tar -xzf redis.tar.gz -C /usr/src/redis --strip-components=1 && \
    cd /usr/src/redis/src && \
    make BUILD_TLS=yes MALLOC=libc redis-cli && \
    cp redis-cli /usr/bin/redis-cli && \
    cd && \
    redis-cli -v

ADD hooks /hooks
ADD engine /engine
