.PHONY: docker docker-run install uninstall all clean

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
	docker build -t zfnd-seeder:latest -f Dockerfile .

docker-run:
	docker run --rm -p 53:8053/udp -p 53:8053/tcp -p 8080 zfnd-seeder:latest
