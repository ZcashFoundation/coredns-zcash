# Zcash DNS Seeder

This repo contains scripts for building and deploying the Zcash Foundation's DNS seeder. There are several options for how to deploy a seeder of your own:

### Docker

To build the container, run either `make docker` or `docker build -t zfnd-seeder:latest -f Dockerfile .`.

To run the container, use `make docker-run` or `docker run --rm -p 53:8053/udp -p 53:8053/tcp -p 8080 zfnd-seeder:latest`. That will bind the DNS listener to the host's port 53 and leave `:8080`, which is an HTTP health check endpoint, floating in Docker's automatic port mappings. The seeder is stateless so it's fine to `--rm` the containers when they exit.

If you want to override the default Corefile (and you should because it won't work with your domain), mount a volume over `/etc/dnsseeder/Corefile`.

### Debian package

TODO

### Deploying from binary to a generic systemd Linux

TODO

### Deploying from source to a generic systemd Linux

Clone this repo to the machine you want to deploy to, which will need to have a working Go build environment. Then run `sudo make install` and you're good to go. If you'd prefer not to do that, the only part of the build and install process that actually *needs* elevated permissions is linking the systemd configuration.

Further down the rabbit hole, you can look at what `scripts/build.sh` and `scripts/install_systemd.sh` do and then do that manually instead. It's Go, so you can pretty much just `scp` the coredns binary and Corefile to wherever you want.

## DNS configuration

Let's say you want to configure seeders for the Zcash mainnet and testnet under the domain `dnsseed.example.com`. Then you would add an `NS` record for the subdomain `dnsseed` under your `example.com` configuration pointing to the address where you've deployed the seeder. The seeder will automatically respond to any subdomains as configured, so if your Corefile looks like [the default](coredns/Corefile) you'll end up with `mainnet.dnsseed.example.com` and `testnet.dnsseed.example.com`.
