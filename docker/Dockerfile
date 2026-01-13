ARG GO_VERSION=1.21.0
ARG ALPINE_VERSION=3.18
ARG COREDNS_VERSION=1.11.1
ARG DNSSEEDER_VERSION=v0.4.0

FROM coredns/coredns:${COREDNS_VERSION} AS coredns

FROM golang:${GO_VERSION}-alpine${ALPINE_VERSION} AS builder

RUN apk --no-cache add \
	ca-certificates \
	libcap \
	git \
	make

ARG COREDNS_VERSION
ARG DNSSEEDER_VERSION

RUN git clone --depth 1 --branch v${COREDNS_VERSION} https://github.com/coredns/coredns /go/src/github.com/coredns/coredns

WORKDIR /go/src/github.com/coredns/coredns

RUN echo "dnsseed:github.com/zcashfoundation/dnsseeder/dnsseed" >> /go/src/github.com/coredns/coredns/plugin.cfg
# Must be the same replace as in `dnsseeder`. Currently pointing to "master" branch
RUN echo "replace github.com/btcsuite/btcd => github.com/ZcashFoundation/btcd v0.22.0-beta.0.20220607000607-40dc9492aa42" >> /go/src/github.com/coredns/coredns/go.mod

RUN go get github.com/zcashfoundation/dnsseeder/dnsseed@${DNSSEEDER_VERSION}

RUN make all && \
	setcap cap_net_bind_service=+ep ./coredns

FROM alpine:${ALPINE_VERSION} AS runner

LABEL maintainer="Zcash Foundation <engineers@zfnd.org>"
LABEL org.opencontainers.image.source="https://github.com/ZcashFoundation/coredns-zcash"
LABEL org.opencontainers.image.description="Zcash DNS Seeder - CoreDNS with dnsseed plugin"
LABEL org.opencontainers.image.licenses="MIT"

RUN apk --no-cache add bind-tools

# Configuration environment variables with ZFND defaults
# Override these for custom deployments
ENV HEALTHCHECK_DOMAIN="mainnet.seeder.zfnd.org"

COPY --from=builder /go/src/github.com/coredns/coredns/coredns /usr/bin/coredns
COPY --from=coredns /etc/ssl/certs /etc/ssl/certs

# Copy default ZFND Corefile - mount a volume to override
COPY coredns/Corefile /etc/dnsseeder/Corefile

USER nobody:nobody

# DNS will bind to 53
EXPOSE 53 53/udp

# Health check using configurable domain (shell form for variable expansion)
HEALTHCHECK --interval=5s --retries=10 CMD dig @0.0.0.0 $HEALTHCHECK_DOMAIN +dnssec >/dev/null

# Start CoreDNS with configuration file
ENTRYPOINT ["coredns"]
CMD ["-conf", "/etc/dnsseeder/Corefile"]
