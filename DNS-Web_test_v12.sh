#!/bin/bash

DOMAINS=("www.bahn.de" "www.dhl.de" "www.wetter.com")
OUTPUT_FILE="dns_test_results_v12.csv"
INTERNAL_DNS="Hidden"

echo "timestamp,domain,test_no,dns_server,ttl,hop_count,public_ip_ifconfig,public_ip_ipinfo,dns_lookup_time,ping_time,ttl_ping,tcp_connect_time,tls_handshake_time,ttfb,total_time,internal_dns_query_time,internal_dns_ttl,default_dns_ttl" > "$OUTPUT_FILE"

for DOMAIN in "${DOMAINS[@]}"; do
    for ((i=1; i<=100; i++)); do
        TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
        UNIQUE_PREFIX=$(date +%s)
        BUSTED_DOMAIN="${UNIQUE_PREFIX}.${DOMAIN}"

        DNS_SERVER=$(nslookup "$DOMAIN" 2>/dev/null | awk '/Server:/ {print $2; exit}')

        TRACEROUTE_OUTPUT=$(traceroute -4 -n -w 2 -q 1 "$DOMAIN" 2>/dev/null)
        TTL=$(echo "$TRACEROUTE_OUTPUT" | awk 'END {print $1}')
        [[ ! "$TTL" =~ ^[0-9]+$ ]] && TTL="N/A"
        HOP_COUNT=$(echo "$TRACEROUTE_OUTPUT" | tail -n +2 | wc -l)
        [[ "$HOP_COUNT" -eq 0 ]] && HOP_COUNT="N/A"

        PUBLIC_IP_IFCONFIG=$(curl -s ifconfig.me)
        PUBLIC_IP_IPINFO=$(curl -s ipinfo.io/ip)

        DIG_LOOKUP=$(dig "$BUSTED_DOMAIN" +noall +stats 2>/dev/null)
        DNS_LOOKUP_TIME=$(echo "$DIG_LOOKUP" | awk '/Query time:/ {print $4}')
        [[ -z "$DNS_LOOKUP_TIME" ]] && DNS_LOOKUP_TIME="N/A"

        PING_OUTPUT=$(ping -c 1 "$DOMAIN" 2>/dev/null)
        PING_TIME=$(echo "$PING_OUTPUT" | grep 'time=' | sed -E 's/.*time=([0-9.]+) ms.*/\1/')
        TTL_PING=$(echo "$PING_OUTPUT" | grep 'ttl=' | sed -E 's/.*ttl=([0-9]+).*/\1/')
        [[ -z "$PING_TIME" ]] && PING_TIME="N/A"
        [[ -z "$TTL_PING" ]] && TTL_PING="N/A"

        read TCP_TIME TLS_TIME TTFB_TIME TOTAL_TIME <<< $(curl -o /dev/null -s -w "%{time_connect} %{time_appconnect} %{time_starttransfer} %{time_total}" "https://$DOMAIN")

        DIG_INTERNAL=$(dig @"$INTERNAL_DNS" "$BUSTED_DOMAIN" +noall +stats 2>/dev/null)
        INTERNAL_DNS_QUERY_TIME=$(echo "$DIG_INTERNAL" | awk '/Query time:/ {print $4}')
        INTERNAL_DNS_TTL=$(dig @"$INTERNAL_DNS" "$DOMAIN" +noall +answer | awk '{print $2}' | head -n1)
        [[ -z "$INTERNAL_DNS_QUERY_TIME" ]] && INTERNAL_DNS_QUERY_TIME="N/A"
        [[ -z "$INTERNAL_DNS_TTL" ]] && INTERNAL_DNS_TTL="N/A"

        DEFAULT_DNS_TTL=$(dig "$DOMAIN" +noall +answer | awk '{print $2}' | head -n1)
        [[ -z "$DEFAULT_DNS_TTL" ]] && DEFAULT_DNS_TTL="N/A"

        echo "$TIMESTAMP,$DOMAIN,$i,$DNS_SERVER,$TTL,$HOP_COUNT,$PUBLIC_IP_IFCONFIG,$PUBLIC_IP_IPINFO,$DNS_LOOKUP_TIME,$PING_TIME,$TTL_PING,$TCP_TIME,$TLS_TIME,$TTFB_TIME,$TOTAL_TIME,$INTERNAL_DNS_QUERY_TIME,$INTERNAL_DNS_TTL,$DEFAULT_DNS_TTL" >> "$OUTPUT_FILE"

        echo "[$TIMESTAMP] Test $i for $DOMAIN done. DNS=$DNS_SERVER Ping=$PING_TIME ms TTL=$TTL_PING DNSLookup=$DNS_LOOKUP_TIME ms InternalDNS=$INTERNAL_DNS_QUERY_TIME ms"

        sleep 10
    done
done
