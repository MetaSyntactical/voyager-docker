ARG ALPINE_VERSION=3.17
ARG THTTPD_VERSION=2.29
ARG TRAEFIK_VERSION=3.0.0-beta2
ARG DNSMASQ_VERSION=2.87
ARG S6_OVERLAY_VERSION=3.1.4.1
ARG TRAEFIKMANAGER_VERSION=1.0.0

FROM alpine:$ALPINE_VERSION AS builder-thttpd
ARG ALPINE_VERSION
ARG THTTPD_VERSION
RUN apk add gcc musl-dev make
RUN set -ex; \
    wget --quiet -O /tmp/thttpd.tar.gz "https://acme.com/software/thttpd/thttpd-${THTTPD_VERSION}.tar.gz"; \
    tar xzf /tmp/thttpd.tar.gz -C /tmp thttpd-${THTTPD_VERSION}; \
    mv /tmp/thttpd-${THTTPD_VERSION} /tmp/thttpd; \
    cd /tmp/thttpd; \
    ./configure; \
    make CCOPT='-O2 -g -static' thttpd; \
    install -m 755 thttpd /usr/local/bin


FROM alpine:$ALPINE_VERSION AS builder-traefik
ARG ALPINE_VERSION
ARG TRAEFIK_VERSION
RUN apk --no-cache add ca-certificates tzdata
RUN set -ex; \
    apkArch="$(apk --print-arch)"; \
    case "$apkArch" in \
        armhf) arch='armv6' ;; \
        aarch64) arch='arm64' ;; \
        x86_64) arch='amd64' ;; \
        s390x) arch='s390x' ;; \
        *) echo >&2 "error: unsupported architecture: $apkArch"; exit 1 ;; \
    esac; \
    wget --quiet -O /tmp/traefik.tar.gz "https://github.com/traefik/traefik/releases/download/v${TRAEFIK_VERSION}/traefik_v${TRAEFIK_VERSION}_linux_$arch.tar.gz"; \
    tar xzf /tmp/traefik.tar.gz -C /usr/local/bin traefik; \
    rm -f /tmp/traefik.tar.gz; \
    chmod +x /usr/local/bin/traefik


FROM alpine:$ALPINE_VERSION AS builder-traefikmanager
ARG ALPINE_VERSION
ARG TRAEFIKMANAGER_VERSION
RUN apk --no-cache add ca-certificates tzdata
RUN set -ex; \
    apkArch="$(apk --print-arch)"; \
    case "$apkArch" in \
        aarch64) arch='arm64' ;; \
        x86_64) arch='x86_64' ;; \
        *) echo >&2 "error: unsupported architecture: $apkArch"; exit 1 ;; \
    esac; \
    wget --quiet -O /tmp/voyager-traefik-manager.tar.gz "https://github.com/MetaSyntactical/voyager-traefik-manager/releases/download/${TRAEFIKMANAGER_VERSION}/voyager-traefik-manager_linux_$arch.tar.gz"; \
    tar xzf /tmp/voyager-traefik-manager.tar.gz -C /usr/local/bin voyager-traefik-manager; \
    rm -f /tmp/voyager-traefik-manager.tar.gz; \
    chmod +x /usr/local/bin/voyager-traefik-manager


FROM alpine:$ALPINE_VERSION AS builder-s6
ARG ALPINE_VERSION
ARG S6_OVERLAY_VERSION
RUN set -ex; \
    apkArch="$(apk --print-arch)"; \
    arch="$apkArch"; \
    wget --quiet -O /tmp/s6-overlay-noarch.tar.xz "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz"; \
    wget --quiet -O /tmp/syslogd-overlay-noarch.tar.xz "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/syslogd-overlay-noarch.tar.xz"; \
    wget --quiet -O /tmp/s6-overlay-${arch}.tar.xz "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${arch}.tar.xz"; \
    tar -Jxpf /tmp/s6-overlay-noarch.tar.xz -C /tmp; \
    tar -Jxpf /tmp/syslogd-overlay-noarch.tar.xz -C /tmp; \
    tar -Jxpf /tmp/s6-overlay-${arch}.tar.xz -C /tmp; \
    rm /tmp/s6-overlay-*.tar.xz


FROM alpine:$ALPINE_VERSION AS builder-envsubst
ARG ALPINE_VERSION
RUN set -ex; \
    apk add --no-cache --update libintl gettext; \
    mkdir -p /tmp/package/usr/local/bin; \
    mkdir -p /tmp/package/usr/lib; \
    cp /usr/bin/envsubst /tmp/package/usr/local/bin; \
    cp /usr/lib/libintl.so.* /tmp/package/usr/lib


FROM alpine:$ALPINE_VERSION AS final
ARG ALPINE_VERSION
ARG DNSMASQ_VERSION
ENV LANG='en_US.UTF-8' \
    LANGUAGE='en_US.UTF-8' \
    TERM='xterm'
ENV BASE_DOMAIN='docker'
LABEL com.metasyntactical.voyager.proxy.domain=docker
LABEL com.metasyntactical.voyager.proxy.tls=true
COPY files/ /
RUN set -ex; \
    chmod +x /usr/local/bin/bootstrap-*.sh
RUN set -ex; \
    apk --no-cache add ca-certificates tzdata; \
    apk --no-cache add dnsmasq=~${DNSMASQ_VERSION}
COPY --from=builder-thttpd /usr/local/bin/thttpd /usr/local/bin
COPY --from=builder-traefik /usr/local/bin/traefik /usr/local/bin
COPY --from=builder-traefikmanager /usr/local/bin/voyager-traefik-manager /usr/local/bin
COPY --from=builder-envsubst /tmp/package/ /
COPY --from=builder-s6 /tmp /
EXPOSE 53/udp 80/tcp 443/tcp 8080/tcp
ENTRYPOINT ["/init"]
