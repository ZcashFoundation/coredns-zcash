.PHONY: docker docker-run docker-clean install uninstall all clean

VERSION=v0.1.0

all: build_output/coredns

clean:
	rm -rf build_output

build_output:
	mkdir build_output

build_output/coredns: build_output
	bash scripts/build.sh

install: build_output/coredns
	bash scripts/install_systemd.sh

uninstall:
	bash scripts/uninstall_systemd.sh

docker:
	docker build -t zfnd-seeder:$(VERSION) -f Dockerfile .

docker-run:
	docker run -d --rm -p 1053:8053/udp -p 1053:8053/tcp -p 8080 zfnd-seeder:$(VERSION)

docker-clean:
	docker rmi zfnd-seeder:$(VERSION)
