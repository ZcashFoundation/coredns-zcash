ARG GO_VERSION=1.21.0
ARG ALPINE_VERSION=3.18
ARG COREDNS_VERSION=1.11.1
ARG DNSSEEDER_VERSION=v0.2.4

FROM coredns/coredns:${COREDNS_VERSION} AS coredns

FROM golang:${GO_VERSION}-alpine${ALPINE_VERSION} AS builder
LABEL maintainer "Zcash Foundation <engineers@zfnd.org>"

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

RUN apk --no-cache add bind-tools

USER nobody:nobody

COPY --from=builder /go/src/github.com/coredns/coredns/coredns /usr/bin/coredns
COPY --from=coredns /etc/ssl/certs /etc/ssl/certs

COPY coredns/Corefile /etc/coredns/Corefile

# DNS will bind to 53
EXPOSE 53 53/udp

# Check if the Coredns container is healthy
HEALTHCHECK --interval=5s --retries=10 CMD dig @0.0.0.0 mainnet.seeder.zfnd.org +dnssec >/dev/null

# Start coredns with custom configuration file
ENTRYPOINT ["coredns"]
CMD ["-conf", "/etc/coredns/Corefile"]
