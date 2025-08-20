#!/bin/bash

# dns_test_v15.sh
# DNS responsiveness test with traceroute vs ping hop comparison, cache busting, internal DNS timing, and full network metrics

DOMAINS=("www.bahn.de" "www.dhl.de" "www.wetter.com")
OUTPUT_FILE="dns_test_results_v15.csv"
INTERNAL_DNS="Hidden"
INITIAL_TTL=64

# Write CSV header
echo "timestamp,domain,test_no,dns_server,hop_count_traceroute,hop_count_ping,public_ip_ifconfig,public_ip_ipinfo,private_ip_ifconfig,dns_lookup_time,ping_time,ttl_ping,tcp_connect_time,tls_handshake_time,ttfb,total_time,internal_dns_query_time,internal_dns_ttl,default_dns_ttl" > "$OUTPUT_FILE"

for DOMAIN in "${DOMAINS[@]}"; do
    for ((i=1; i<=5; i++)); do
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
        HOP_COUNT_PING=$((INITIAL_TTL - TTL_PING))

        read TCP_TIME TLS_TIME TTFB_TIME TOTAL_TIME <<< $(curl -o /dev/null -s -w "%{time_connect} %{time_appconnect} %{time_starttransfer} %{time_total}" "https://$DOMAIN")

        DIG_INTERNAL=$(dig @"$INTERNAL_DNS" "$BUSTED_DOMAIN" +noall +stats 2>/dev/null)
        INTERNAL_DNS_QUERY_TIME=$(echo "$DIG_INTERNAL" | awk '/Query time:/ {print $4}')
        INTERNAL_DNS_TTL=$(dig @"$INTERNAL_DNS" "$DOMAIN" +noall +answer | awk '{print $2}' | head -n1)

        DEFAULT_DNS_TTL=$(dig "$DOMAIN" +noall +answer | awk '{print $2}' | head -n1)

        echo "$TIMESTAMP,$DOMAIN,$i,$DNS_SERVER,$HOP_COUNT_TRACEROUTE,$HOP_COUNT_PING,$PUBLIC_IP_IFCONFIG,$PUBLIC_IP_IPINFO,$PRIVATE_IP_IFCONFIG,$DNS_LOOKUP_TIME,$PING_TIME,$TTL_PING,$TCP_TIME,$TLS_TIME,$TTFB_TIME,$TOTAL_TIME,$INTERNAL_DNS_QUERY_TIME,$INTERNAL_DNS_TTL,$DEFAULT_DNS_TTL" >> "$OUTPUT_FILE"

        echo "[$TIMESTAMP] Test $i for $DOMAIN done. DNS=$DNS_SERVER Ping=$PING_TIME ms TTL=$TTL_PING HopPing=$HOP_COUNT_PING DNSLookup=$DNS_LOOKUP_TIME ms InternalDNS=$INTERNAL_DNS_QUERY_TIME ms"

        sleep 10
    done
done

