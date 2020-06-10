.PHONY: docker docker-run docker-clean install uninstall all clean

BUILD_DIR=build_output
VERSION=v0.1.1

all: coredns-zcash_${VERSION}.tgz

coredns-zcash_${VERSION}.tgz: ${BUILD_DIR}/coredns
	tar czf coredns-zcash_${VERSION}.tgz ${BUILD_DIR}/ scripts/ coredns/ systemd/

clean:
	rm -rf ${BUILD_DIR}
	rm coredns-zcash_${VERSION}.tgz

${BUILD_DIR}:
	mkdir -p ${BUILD_DIR}

${BUILD_DIR}/coredns: ${BUILD_DIR}
	bash scripts/build.sh

install: ${BUILD_DIR}/coredns
	bash scripts/install_systemd.sh

uninstall:
	bash scripts/uninstall_systemd.sh

docker:
	docker build -t zfnd-seeder:$(VERSION) -f Dockerfile .

docker-run:
	docker run -d --rm -p 1053:53/udp -p 1053:53/tcp -p 8080 zfnd-seeder:$(VERSION)

docker-clean:
	docker rmi zfnd-seeder:$(VERSION)
