# Zcash DNS Seeder

This repo contains scripts for building and deploying the Zcash Foundation's DNS seeder. There are several options for how to deploy a seeder of your own:

### Docker

To build the container, run either `make docker` or `docker build -t zfnd-seeder:latest -f Dockerfile .`.

To run the container, use `make docker-run` or `docker run --rm -p 1053:53/udp -p 1053:53/tcp zfnd-seeder:latest`. That will bind the DNS listener to the host's port 1053. You could also use `--network host` if you want to bind to the host's port 53 directly. The seeder is stateless so it's fine to `--rm` the containers when they exit.

If you want to override the default Corefile (and you should because it won't work with your domain), mount a volume over `/etc/dnsseeder/Corefile`.

### Google Compute Engine

The container built here is designed to run on a GCP Container OS VM, but you'll need to use a start script to disable the systemd stub resolver and mount an appropriate configuration to `/etc/dnsseeder/Corefile`. An example is available in `scripts/gcp-start.sh`, which both stops the systemd resolver and drops the config file in an appropriate place for a host volume mount.

### Debian package

TODO

### Deploying from binary to a generic systemd Linux

Check the releases page for a tarball. Extract the contents anywhere, change to that directory, then run `sudo make install`. Then edit `/etc/dnsseeder/Corefile` to replace instances of "example.com" with your desired DNS names.

### Deploying from source to a generic systemd Linux

Clone this repo to the machine you want to deploy to, which will need to have a working Go build environment. Then run `sudo make install`, edit `/etc/dnsseeder/Corefile` with your DNS names, and you're good to go. If you'd prefer not to do that, the only part of the build and install process that actually *needs* elevated permissions is linking the systemd configuration.

Further down the rabbit hole, you can look at what `scripts/build.sh` and `scripts/install_systemd.sh` do and then do that manually instead. It's Go, so you can pretty much just `scp` the coredns binary and Corefile to wherever you want.

To remove the seeder, run `scripts/uninstall_systemd.sh`.

## DNS configuration

Let's say you want to configure seeders for the Zcash mainnet and testnet under the domain `dnsseed.example.com`. Then you would add an `NS` record for the subdomain `dnsseed` under your `example.com` configuration pointing to the address where you've deployed the seeder. The seeder will automatically respond to any subdomains as configured, so if your Corefile looks like [the default](coredns/Corefile) you'll end up with `mainnet.dnsseed.example.com` and `testnet.dnsseed.example.com`.
