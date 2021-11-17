FROM golang:1.17.3-alpine3.14 as builder
LABEL maintainer "Zcash Foundation <engineers@zfnd.org>"

ENV PATH /go/bin:/usr/local/go/bin:$PATH
ENV GOPATH /go

RUN apk --no-cache add \
	bash \
	ca-certificates \
	git \
	make

ENV COREDNS_VERSION v1.6.9
# TODO: change to "main" or tagged version
ENV DNSSEEDER_VERSION addrv2

RUN git clone --depth 1 --branch ${COREDNS_VERSION} https://github.com/coredns/coredns /go/src/github.com/coredns/coredns

WORKDIR /go/src/github.com/coredns/coredns

RUN echo "dnsseed:github.com/zcashfoundation/dnsseeder/dnsseed" >> /go/src/github.com/coredns/coredns/plugin.cfg
# Branch "addrv2". TODO: change to "main-zfnd" or tagged version
RUN echo "replace github.com/btcsuite/btcd => github.com/ZcashFoundation/btcd v0.22.0-beta.0.20211116150640-079ebf598ccb" >> /go/src/github.com/coredns/coredns/go.mod

RUN go get github.com/zcashfoundation/dnsseeder/dnsseed@${DNSSEEDER_VERSION}

RUN make all \
	&& mv coredns /usr/bin/coredns


FROM alpine:latest

RUN apk --no-cache add libcap

COPY --from=builder /usr/bin/coredns /usr/bin/coredns
COPY --from=builder /etc/ssl/certs/ /etc/ssl/certs

COPY coredns/Corefile /etc/dnsseeder/Corefile

RUN setcap 'cap_net_bind_service=+ep' /usr/bin/coredns

# DNS will bind to 53
EXPOSE 53

VOLUME /etc/dnsseeder

RUN adduser --disabled-password dnsseeder
USER dnsseeder

ENTRYPOINT [ "coredns" ]
CMD [ "-conf", "/etc/dnsseeder/Corefile"]
