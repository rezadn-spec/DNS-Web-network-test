#!/bin/bash

DOMAINS=("https://business.x.com/en/help/troubleshooting/how-x-ads-work.html" "https://redditinc.com" "https://workspace.google.com/products/meet" "https://www.bahn.de/service/ueber-uns/umwelt" "https://www.dhl.de/de/privatkunden.html" "https://www.wetter.com/newsletter" "https://www.yahooinc.com/about" "https://www.zdf.de")
OUTPUT_FILE="/storage/emulated/0/Download/dns_test_results_v17.csv"
INTERNAL_DNS="61.8.132.52"
INITIAL_TTL=64
WAIT_BETWEEN_DOMAINS=12
WAIT_BETWEEN_CYCLES=1800

if [ ! -f "$OUTPUT_FILE" ]; then
    echo "timestamp,domain,cycle_no,dns_server,hop_count_traceroute,hop_count_ping,public_ip_ifconfig,public_ip_ipinfo,private_ip_ifconfig,dns_lookup_time,ping_time,ttl_ping,tcp_connect_time,tls_handshake_time,ttfb,total_time,internal_dns_query_time,internal_dns_ttl,default_dns_ttl" > "$OUTPUT_FILE"
    sync
fi

cycle=1

while true; do
    echo "=== Starting test cycle $cycle at $(date '+%Y-%m-%d %H:%M:%S') ==="
    
    for DOMAIN in "${DOMAINS[@]}"; do
        TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
        UNIQUE_PREFIX=$(date +%s)
        BUSTED_DOMAIN="${UNIQUE_PREFIX}.${DOMAIN}"

        DNS_SERVER=$(nslookup "$DOMAIN" 2>/dev/null | awk '/Server:/ {print $2; exit}')
        TRACEROUTE_OUTPUT=$(traceroute -4 -n -w 2 -q 1 "$DOMAIN" 2>/dev/null)
        HOP_COUNT_TRACEROUTE=$(echo "$TRACEROUTE_OUTPUT" | tail -n +2 | wc -l)

        PUBLIC_IP_IFCONFIG=$(curl -s ifconfig.me)
        PUBLIC_IP_IPINFO=$(curl -s ipinfo.io/ip)
        PRIVATE_IP_IFCONFIG=$(ifconfig 2>/dev/null | awk '/rmnet/ {iface=$1} $1 == "inet" && iface != "" {print $2; exit}')

        DIG_LOOKUP=$(dig "$BUSTED_DOMAIN" +noall +stats 2>/dev/null)
        DNS_LOOKUP_TIME=$(echo "$DIG_LOOKUP" | awk '/Query time:/ {print $4}')

        PING_OUTPUT=$(ping -c 1 "$DOMAIN" 2>/dev/null)
        PING_TIME=$(echo "$PING_OUTPUT" | grep 'time=' | sed -E 's/.*time=([0-9.]+) ms.*/\1/')
        TTL_PING=$(echo "$PING_OUTPUT" | grep 'ttl=' | sed -E 's/.*ttl=([0-9]+).*/\1/')
        HOP_COUNT_PING=""
        [ -n "$TTL_PING" ] && HOP_COUNT_PING=$((INITIAL_TTL - TTL_PING))

        read TCP_TIME TLS_TIME TTFB_TIME TOTAL_TIME <<< $(curl -o /dev/null -s -w "%{time_connect} %{time_appconnect} %{time_starttransfer} %{time_total}" "https://$DOMAIN")

        DIG_INTERNAL=$(dig @"$INTERNAL_DNS" "$BUSTED_DOMAIN" +noall +stats 2>/dev/null)
        INTERNAL_DNS_QUERY_TIME=$(echo "$DIG_INTERNAL" | awk '/Query time:/ {print $4}')
        INTERNAL_DNS_TTL=$(dig @"$INTERNAL_DNS" "$DOMAIN" +noall +answer | awk '{print $2}' | head -n1)

        DEFAULT_DNS_TTL=$(dig "$DOMAIN" +noall +answer | awk '{print $2}' | head -n1)

        echo "$TIMESTAMP,$DOMAIN,$cycle,$DNS_SERVER,$HOP_COUNT_TRACEROUTE,$HOP_COUNT_PING,$PUBLIC_IP_IFCONFIG,$PUBLIC_IP_IPINFO,$PRIVATE_IP_IFCONFIG,$DNS_LOOKUP_TIME,$PING_TIME,$TTL_PING,$TCP_TIME,$TLS_TIME,$TTFB_TIME,$TOTAL_TIME,$INTERNAL_DNS_QUERY_TIME,$INTERNAL_DNS_TTL,$DEFAULT_DNS_TTL" >> "$OUTPUT_FILE"
        sync

        echo "[$TIMESTAMP] Cycle $cycle: $DOMAIN done. DNS=$DNS_SERVER Ping=$PING_TIME ms DNSLookup=$DNS_LOOKUP_TIME ms InternalDNS=$INTERNAL_DNS_QUERY_TIME ms"
        sleep $WAIT_BETWEEN_DOMAINS
    done

    echo "=== Cycle $cycle completed at $(date '+%Y-%m-%d %H:%M:%S'). Waiting 30 minutes before next cycle. ==="
    ((cycle++))
    sleep $WAIT_BETWEEN_CYCLES
done
