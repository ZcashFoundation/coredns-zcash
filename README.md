# Zcash DNS Seeder

This repository contains the Zcash Foundation's DNS seeder, built on CoreDNS with a custom dnsseed plugin. The seeder helps new Zcash wallets and nodes discover peers on the network.

**Default Configuration**: The container ships with ZFND defaults (`mainnet.seeder.zfnd.org` and `testnet.seeder.zfnd.org`). Most organizations can deploy as-is; others can customize the configuration.

## Quick Start

### Docker (Recommended)

Build and run with ZFND defaults:

```bash
# Build
make docker
# or
docker build -t zfnd-seeder:latest -f docker/Dockerfile .

# Run (binds to port 1053 for testing)
docker run --rm -p 1053:53/udp -p 1053:53/tcp zfnd-seeder:latest

# Run in production (binds to port 53)
docker run -d --network host zfnd-seeder:latest
```

### Custom Configuration

To use your own domain, mount a custom Corefile:

```bash
docker run -d --network host \
  -v /path/to/your/Corefile:/etc/dnsseeder/Corefile:ro \
  -e HEALTHCHECK_DOMAIN="mainnet.seeder.example.com" \
  zfnd-seeder:latest
```

## Deployment Options

### Docker

The container is stateless and can be safely restarted. Configuration is loaded from `/etc/dnsseeder/Corefile`.

**Environment Variables:**

| Variable | Default | Description |
|----------|---------|-------------|
| `HEALTHCHECK_DOMAIN` | `mainnet.seeder.zfnd.org` | Domain used for container health checks |

### Google Compute Engine

For GCP Container OS VMs:

1. Use `scripts/gcp-start.sh` as the startup script
2. The script stops systemd-resolved to free port 53
3. The container uses its built-in Corefile with ZFND defaults

See `scripts/deploy-seeders.sh` for a multi-zone deployment example.

To customize the Corefile, create `/etc/dnsseeder/Corefile` on the host and mount it into the container.

### Systemd (Linux)

**From binary:**

1. Download the release tarball from the releases page
2. Extract and run `sudo make install`
3. Edit `/etc/dnsseeder/Corefile` with your DNS names
4. The seeder runs as a systemd service

**From source:**

1. Clone this repo (requires Go build environment)
2. Run `sudo make install`
3. Edit `/etc/dnsseeder/Corefile` with your DNS names

To uninstall: `sudo scripts/uninstall_systemd.sh`

## Configuration

### Corefile

The Corefile defines which domains the seeder responds to and how it discovers peers. Example:

```
mainnet.seeder.example.com {
    dnsseed {
        network mainnet
        bootstrap_peers dnsseed.str4d.xyz:8233 34.138.164.8:8233
        crawl_interval 30m
        record_ttl 600
    }
    log {
        class denial error
    }
}

testnet.seeder.example.com {
    dnsseed {
        network testnet
        bootstrap_peers 34.23.160.180:18233
        crawl_interval 15m
        record_ttl 300
    }
    log {
        class denial error
    }
}
```

### DNS Setup

To configure seeders for `dnsseed.example.com`:

1. Deploy the seeder to a server with a static IP
2. Add an `NS` record for `dnsseed` subdomain pointing to your seeder's hostname
3. Add an `A` record for the seeder hostname pointing to its IP

The seeder responds to subdomains as configured in the Corefile (e.g., `mainnet.dnsseed.example.com`).

## Testing

Query your seeder to verify it's working:

```bash
# Test with a specific IP
dig @<seeder-ip> mainnet.seeder.zfnd.org +short

# Test ZFND production seeders
dig mainnet.seeder.zfnd.org +short
dig testnet.seeder.zfnd.org +short
```

## Non-Zcash Networks

To use the seeder on a non-Zcash network:

1. Choose a unique magic value and port for your network
2. Choose an initial network protocol version
3. Fork and modify the [dnsseeder](https://github.com/ZcashFoundation/dnsseeder) plugin:
   - `zcash/client.go` - Protocol settings
   - `zcash/network/params.go` - Network parameters
   - `zcash/network/magic.go` - Network magic bytes

If the message format differs from Zcash (`version`, `verack`, `ping`, `pong`, `getaddr`, `addr`), update the seeder accordingly.

## Development

```bash
# Build locally
make all

# Build Docker image
make docker

# Run tests
make docker-run
dig @localhost -p 1053 mainnet.seeder.zfnd.org +short
```

## License

MIT License - See LICENSE file for details.
