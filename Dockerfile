FROM alpine:3.11

LABEL maintainer="David Staeheli <david@hosa.ch>" \
    description="Eclipse Mosquitto MQTT Broker"

ENV VERSION=1.6.9 \
    DOWNLOAD_SHA256=412979b2db0a0020bd02fa64f0a0de9e7000b84462586e32b67f29bb1f6c1685 \
    GPG_KEYS=A0D6EEA1DCAE49A635A3B2F0779B22DFB3E717B7 \
    LWS_VERSION=2.4.2

RUN addgroup -S -g 1883 mosquitto 2>/dev/null && \
    adduser -S -u 1883 -D -H -h /var/empty -s /sbin/nologin -G mosquitto -g mosquitto mosquitto 2>/dev/null

RUN apk add libcurl mongo-c-driver

RUN set -x && \
    apk --no-cache add --virtual build-deps \
        build-base \
        cmake \
        gnupg \
        libressl-dev \
        sed \
        git \
        c-ares-dev \
        curl-dev \
        mongo-c-driver-dev \
        util-linux-dev && \
    wget https://github.com/warmcat/libwebsockets/archive/v${LWS_VERSION}.tar.gz -O /tmp/lws.tar.gz && \
    mkdir -p /build/lws && \
    tar --strip=1 -xf /tmp/lws.tar.gz -C /build/lws && \
    rm /tmp/lws.tar.gz && \
    cd /build/lws && \
    cmake . \
        -DCMAKE_BUILD_TYPE=MinSizeRel \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DLWS_IPV6=ON \
        -DLWS_WITHOUT_BUILTIN_GETIFADDRS=ON \
        -DLWS_WITHOUT_CLIENT=ON \
        -DLWS_WITHOUT_EXTENSIONS=ON \
        -DLWS_WITHOUT_TESTAPPS=ON \
        -DLWS_WITH_SHARED=OFF \
        -DLWS_WITH_ZIP_FOPS=OFF \
        -DLWS_WITH_ZLIB=OFF && \
    make -j "$(nproc)" && \
    rm -rf /root/.cmake && \
    wget https://mosquitto.org/files/source/mosquitto-${VERSION}.tar.gz -O /tmp/mosq.tar.gz && \
    echo "$DOWNLOAD_SHA256  /tmp/mosq.tar.gz" | sha256sum -c - && \
    wget https://mosquitto.org/files/source/mosquitto-${VERSION}.tar.gz.asc -O /tmp/mosq.tar.gz.asc && \
    export GNUPGHOME="$(mktemp -d)" && \
    found=''; \
    for server in \
        ha.pool.sks-keyservers.net \
        hkp://keyserver.ubuntu.com:80 \
        hkp://p80.pool.sks-keyservers.net:80 \
        pgp.mit.edu \
    ; do \
        echo "Fetching GPG key $GPG_KEYS from $server"; \
        gpg --keyserver "$server" --keyserver-options timeout=10 --recv-keys "$GPG_KEYS" && found=yes && break; \
    done; \
    test -z "$found" && echo >&2 "error: failed to fetch GPG key $GPG_KEYS" && exit 1; \
    gpg --batch --verify /tmp/mosq.tar.gz.asc /tmp/mosq.tar.gz && \
    gpgconf --kill all && \
    rm -rf "$GNUPGHOME" /tmp/mosq.tar.gz.asc && \
    mkdir -p /build/mosquitto && \
    tar --strip=1 -xf /tmp/mosq.tar.gz -C /build/mosquitto && \
    rm /tmp/mosq.tar.gz && \
    make -C /build/mosquitto -j "$(nproc)" \
        CFLAGS="-Wall -O2 -I/build/lws/include" \
        LDFLAGS="-L/build/lws/lib" \
        WITH_ADNS=no \
        WITH_DOCS=no \
        WITH_SHARED_LIBRARIES=yes \
        WITH_SRV=no \
        WITH_STRIP=yes \
        WITH_TLS_PSK=no \
        WITH_WEBSOCKETS=yes \
        prefix=/usr \
        binary && \
    mkdir -p /mosquitto/config /mosquitto/data /mosquitto/log && \
    install -d /usr/sbin/ && \
    install -s -m755 /build/mosquitto/client/mosquitto_pub /usr/bin/mosquitto_pub && \
    install -s -m755 /build/mosquitto/client/mosquitto_rr /usr/bin/mosquitto_rr && \
    install -s -m755 /build/mosquitto/client/mosquitto_sub /usr/bin/mosquitto_sub && \
    install -s -m644 /build/mosquitto/lib/libmosquitto.so.1 /usr/lib/libmosquitto.so.1 && \
    ln -sf /usr/lib/libmosquitto.so.1 /usr/lib/libmosquitto.so && \
    install -s -m755 /build/mosquitto/src/mosquitto /usr/sbin/mosquitto && \
    install -s -m755 /build/mosquitto/src/mosquitto_passwd /usr/bin/mosquitto_passwd && \
    install -m644 /build/mosquitto/mosquitto.conf /mosquitto/config/mosquitto.conf && \
    chown -R mosquitto:mosquitto /mosquitto && \
    cd /build/mosquitto/ && \
    git clone https://github.com/vankxr/mosquitto-auth-plug && \
    cd .. && \
    pwd && \
    cd .. && \
    ls -al /build/mosquitto && \
    cp /build/mosquitto/mosquitto-auth-plug/config.mk.in /build/mosquitto/mosquitto-auth-plug/config.mk && \
    sed -i "s/BACKEND_CDB ?= no/BACKEND_CDB ?= no/" /build/mosquitto/mosquitto-auth-plug/config.mk && \
    sed -i "s/BACKEND_MYSQL ?= yes/BACKEND_MYSQL ?= no/" /build/mosquitto/mosquitto-auth-plug/config.mk && \
    sed -i "s/BACKEND_SQLITE ?= no/BACKEND_SQLITE ?= no/" /build/mosquitto/mosquitto-auth-plug/config.mk && \
    sed -i "s/BACKEND_REDIS ?= no/BACKEND_REDIS ?= no/" /build/mosquitto/mosquitto-auth-plug/config.mk && \
    sed -i "s/BACKEND_POSTGRES ?= no/BACKEND_POSTGRES ?= no/" /build/mosquitto/mosquitto-auth-plug/config.mk && \
    sed -i "s/BACKEND_LDAP ?= no/BACKEND_LDAP ?= no/" /build/mosquitto/mosquitto-auth-plug/config.mk && \
    sed -i "s/BACKEND_HTTP ?= no/BACKEND_HTTP ?= yes/" /build/mosquitto/mosquitto-auth-plug/config.mk && \
    sed -i "s/BACKEND_JWT ?= no/BACKEND_JWT ?= no/" /build/mosquitto/mosquitto-auth-plug/config.mk && \
    sed -i "s/BACKEND_MONGO ?= no/BACKEND_MONGO ?= yes/" /build/mosquitto/mosquitto-auth-plug/config.mk && \
    sed -i "s/BACKEND_FILES ?= no/BACKEND_FILES ?= no/" /build/mosquitto/mosquitto-auth-plug/config.mk && \
    sed -i "s/BACKEND_MEMCACHED ?= no/BACKEND_MEMCACHED ?= no/" /build/mosquitto/mosquitto-auth-plug/config.mk && \
    sed -i "s/MOSQUITTO_SRC =/MOSQUITTO_SRC = ..\//" /build/mosquitto/mosquitto-auth-plug/config.mk && \
    make -C /build/mosquitto/mosquitto-auth-plug -j "$(nproc)" && \
    ls -al /build/mosquitto/mosquitto-auth-plug && \
    install -s -m755 /build/mosquitto/mosquitto-auth-plug/auth-plug.so /usr/lib/ && \
    install -s -m755 /build/mosquitto/mosquitto-auth-plug/np /usr/bin/ && \
    apk --no-cache add \
        ca-certificates && \
    apk del build-deps && \
    rm -rf /build && \
    rm -rf /var/cache/apk/*

VOLUME ["/mosquitto/data", "/mosquitto/log"]

# Set up the entry point script and default command
COPY docker-entrypoint.sh /
RUN chmod 655 ./docker-entrypoint.sh
EXPOSE 1883
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["/usr/sbin/mosquitto", "-c", "/mosquitto/config/mosquitto.conf"]
