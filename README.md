# DNS-Web-network-test
Bash script for DNS and web response testing with cache busting, TTL analysis, and internal DNS comparison

# DNS & Web Response Test Script

This bash script performs DNS responsiveness testing with cache busting, internal DNS comparison, ping latency, and TTL analysis. Designed for Linux environments (including Termux on Android).

## Features
- DNS lookup timing
- Ping latency and TTL
- Traceroute hop count
- Internal DNS vs default DNS comparison
- Public IP detection
- Web response timing (TCP, TLS, TTFB)

## Usage
```bash
chmod +x dns_test_v12.sh
./dns_test_v12.sh
