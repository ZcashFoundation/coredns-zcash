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

A DNS seeder is itself a DNS nameserver - it responds to DNS queries with A records containing peer node IPs. This requires proper DNS delegation so queries reach your seeder.

#### Architecture: Direct IPs, Not Proxies

**Each seeder must have its own static external IP address.** Do not place seeders behind a load balancer or proxy:

- **DNS seeders ARE nameservers** - they must receive DNS queries directly on port 53
- **Proxies break DNS** - they would intercept/modify DNS responses, breaking the protocol
- **DNS has built-in load balancing** - use multiple NS records for high availability
- **Geographic distribution matters** - deploy seeders across regions to reduce latency

For high availability, deploy multiple independent seeders and configure DNS round-robin (see below).

#### Single Seeder Setup

For a seeder at `seeder.example.com` with IP `203.0.113.10`:

```dns
; In your example.com DNS zone
; Step 1: Create NS record to delegate the subdomain to your seeder
seeder.example.com.        IN  NS  ns1.seeder.example.com.

; Step 2: Create A record (glue record) for the nameserver itself
ns1.seeder.example.com.    IN  A   203.0.113.10
```

The NS record delegates all queries for `*.seeder.example.com` to your seeder. Your Corefile would then define:

```
mainnet.seeder.example.com { ... }
testnet.seeder.example.com { ... }
```

#### Multi-Seeder High Availability Setup (Recommended)

For production deployments, run multiple seeders across different regions:

```dns
; In your example.com DNS zone
; Multiple NS records for redundancy - DNS will round-robin between them
seeder.example.com.        IN  NS  ns1.seeder.example.com.
seeder.example.com.        IN  NS  ns2.seeder.example.com.
seeder.example.com.        IN  NS  ns3.seeder.example.com.

; Glue records - each nameserver has its own static IP
ns1.seeder.example.com.    IN  A   203.0.113.10    ; US East
ns2.seeder.example.com.    IN  A   203.0.113.20    ; US West
ns3.seeder.example.com.    IN  A   198.51.100.30   ; Europe
```

**Key points:**
- Each seeder runs the same container with the same Corefile
- Each seeder independently crawls the network and maintains its own peer list
- DNS resolvers will query different seeders, providing natural load distribution
- If one seeder fails, DNS resolvers automatically use the others

#### Verification

After configuring DNS, verify the delegation:

```bash
# Check NS records are configured
dig seeder.example.com NS +short
# Should return: ns1.seeder.example.com., ns2.seeder.example.com., etc.

# Query a seeder directly to verify it's responding
dig @203.0.113.10 mainnet.seeder.example.com +short
# Should return a list of Zcash peer IPs

# Test end-to-end resolution
dig mainnet.seeder.example.com +short
# Should return peer IPs (may vary between queries due to round-robin)
```

#### DNS Provider Notes

Most DNS providers support NS delegation. Common setups:

- **Cloudflare**: Add NS records in the DNS dashboard; glue records are added automatically
- **Route 53**: Create NS records in your hosted zone; add A records for glue
- **Google Cloud DNS**: Same as Route 53

Some providers call the A records for nameservers "glue records" - they're required when the nameserver hostname is within the delegated zone.

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
