FROM golang:alpine as builder
LABEL maintainer "George Tankersley <george@zfnd.org>"

ENV PATH /go/bin:/usr/local/go/bin:$PATH
ENV GOPATH /go

RUN apk --no-cache add \
	bash \
	ca-certificates \
	git \
	make

ENV COREDNS_VERSION v1.6.9

RUN git clone --depth 1 --branch ${COREDNS_VERSION} https://github.com/coredns/coredns /go/src/github.com/coredns/coredns

WORKDIR /go/src/github.com/coredns/coredns

RUN echo "dnsseed:github.com/zcashfoundation/dnsseeder/dnsseed" >> /go/src/github.com/coredns/coredns/plugin.cfg
RUN echo "replace github.com/btcsuite/btcd => github.com/gtank/btcd v0.0.0-20191012142736-b43c61a68604" >> /go/src/github.com/coredns/coredns/go.mod

RUN make all \
	&& mv coredns /usr/bin/coredns

FROM alpine:latest

COPY --from=builder /usr/bin/coredns /usr/bin/coredns
COPY --from=builder /etc/ssl/certs/ /etc/ssl/certs

COPY coredns/Corefile /etc/dnsseeder/Corefile

# DNS will bind to 8053
EXPOSE 8053

# Global health check will respond 200 OK on 8080
EXPOSE 8080

VOLUME /etc/dnsseeder

RUN adduser --disabled-password dnsseeder
USER dnsseeder

ENTRYPOINT [ "coredns" ]
CMD [ "-conf", "/etc/dnsseeder/Corefile", "-dns.port", "8053"]
