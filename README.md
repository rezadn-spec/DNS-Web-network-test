# DNS-Web-network-test
Bash script for DNS and web response testing with cache busting, TTL analysis, and internal DNS comparison. A lightweight diagnostic tool for analyzing DNS performance and network topology on mobile devices. Built for Linux-based environments.

# DNS & Web Response Test Script

This bash script performs DNS responsiveness testing with cache busting, internal DNS comparison, ping latency, and TTL analysis. Designed for Linux environments (including Termux on Android).

## Features
- DNS lookup timing
- Ping latency and TTL
- Traceroute hop count
- Internal DNS vs default DNS comparison
- Public IP detection
- Web response timing (TCP, TLS, TTFB)

 ---
 
## What's New in v1.5

### RAN/Private IP Detection
- Extracts the UE’s private IP (typically `10.x.x.x`) from the `rmnet` interface using `ifconfig`.
- Helps correlate DNS performance with the device’s position in the Radio Access Network (RAN).

### Estimated Hop Count from Ping
- Introduced `hop_count_ping`, calculated as:  
  `Estimated hops = Initial TTL (64) − Received TTL`
- Offers an alternative to traceroute for estimating network path length.
- Especially useful when ICMP behavior differs from TCP.

### Metric Renaming
- Renamed `hop_count` to `hop_count_traceroute` for clarity.
- Distinguishes traceroute-based estimates from ping-based ones, improving data readability.

  Reza Dehghan Niri
