#!/bin/bash

TARGETS=(
  "https://business.x.com/en/help/troubleshooting/how-x-ads-work.html"
  "https://redditinc.com/"
  "https://workspace.google.com/products/meet"
  "https://www.bahn.de/service/ueber-uns/umwelt"
  "https://www.dhl.de/de/privatkunden.html"
  "https://www.wetter.com/newsletter/"
  "https://www.yahooinc.com/about"
  "https://www.zdf.de/"
)

INTERNAL_DNS="61.8.132.52"
INITIAL_TTL=64
WAIT_BETWEEN_TARGETS=12
WAIT_BETWEEN_CYCLES=1800
DOWNLOADS_DIR="/storage/emulated/0/Download"
RUN_TS="$(date '+%Y%m%d_%H%M')"
OUTPUT_FILE="${DOWNLOADS_DIR}/dns_results_${RUN_TS}.csv"

if [ ! -f "$OUTPUT_FILE" ]; then
  echo "timestamp,host,url,cycle_no,dns_server,hop_count_traceroute,hop_count_ping,public_ip_ifconfig,public_ip_ipinfo,private_ip_ifconfig,dns_lookup_time_ms,ping_time_ms,ttl_ping,tcp_connect_time_s,tls_handshake_time_s,ttfb_s,total_time_s,internal_dns_query_time_ms,internal_dns_ttl,default_dns_ttl" > "$OUTPUT_FILE"
  sync
fi

cycle=1

while true; do
  echo "=== Starting cycle $cycle at $(date '+%Y-%m-%d %H:%M:%S') ==="

  for URL in "${TARGETS[@]}"; do
    TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
    [[ "$URL" =~ ^https?:// ]] && HOST="$(echo "$URL" | sed -E 's~https?://([^/]+)/?.*~\1~')" || { HOST="$URL"; URL="https://${HOST}"; }
    UNIQUE_PREFIX="$(date +%s)"
    BUSTED_HOST="${UNIQUE_PREFIX}.${HOST}"

    DNS_SERVER="$(nslookup "$HOST" 2>/dev/null | awk '/Server:/ {print $2; exit}')"
    TRACEROUTE_OUTPUT="$(traceroute -4 -n -w 2 -q 1 "$HOST" 2>/dev/null)"
    HOP_COUNT_TRACEROUTE="$(echo "$TRACEROUTE_OUTPUT" | tail -n +2 | wc -l)"

    PUBLIC_IP_IFCONFIG="$(curl -s ifconfig.me)"
    PUBLIC_IP_IPINFO="$(curl -s ipinfo.io/ip)"
    PRIVATE_IP_IFCONFIG="$(ifconfig 2>/dev/null | awk '/rmnet/ {iface=$1} $1 == "inet" && iface != "" {print $2; exit}')"

    DIG_LOOKUP="$(dig "$BUSTED_HOST" +noall +stats 2>/dev/null)"
    DNS_LOOKUP_TIME="$(echo "$DIG_LOOKUP" | awk '/Query time:/ {print $4}')"

    PING_OUTPUT="$(ping -4 -c 1 "$HOST" 2>/dev/null)"
    PING_TIME="$(echo "$PING_OUTPUT" | grep -oE 'time=([0-9.]+) ms' | sed -E 's/time=([0-9.]+) ms/\1/')"
    TTL_PING="$(echo "$PING_OUTPUT" | grep -oE 'ttl=[0-9]+' | sed -E 's/ttl=([0-9]+)/\1/')"
    [ -z "$TTL_PING" ] && TTL_PING="$(echo "$PING_OUTPUT" | grep -oE 'hlim=[0-9]+' | sed -E 's/hlim=([0-9]+)/\1/')"
    HOP_COUNT_PING=""
    [ -n "$TTL_PING" ] && HOP_COUNT_PING=$((INITIAL_TTL - TTL_PING))

    read TCP_TIME TLS_TIME TTFB_TIME TOTAL_TIME <<< "$(curl -o /dev/null -s -w "%{time_connect} %{time_appconnect} %{time_starttransfer} %{time_total}" "$URL")"

    DIG_INTERNAL="$(dig @"$INTERNAL_DNS" "$BUSTED_HOST" +noall +stats 2>/dev/null)"
    INTERNAL_DNS_QUERY_TIME="$(echo "$DIG_INTERNAL" | awk '/Query time:/ {print $4}')"
    INTERNAL_DNS_TTL="$(dig @"$INTERNAL_DNS" "$HOST" +noall +answer | awk '{print $2}' | head -n1)"
    DEFAULT_DNS_TTL="$(dig "$HOST" +noall +answer 2>/dev/null | awk '{print $2}' | head -n1)"

    echo "$TIMESTAMP,$HOST,$URL,$cycle,$DNS_SERVER,$HOP_COUNT_TRACEROUTE,$HOP_COUNT_PING,$PUBLIC_IP_IFCONFIG,$PUBLIC_IP_IPINFO,$PRIVATE_IP_IFCONFIG,$DNS_LOOKUP_TIME,$PING_TIME,$TTL_PING,$TCP_TIME,$TLS_TIME,$TTFB_TIME,$TOTAL_TIME,$INTERNAL_DNS_QUERY_TIME,$INTERNAL_DNS_TTL,$DEFAULT_DNS_TTL" >> "$OUTPUT_FILE"
    sync

    echo "[$TIMESTAMP] Cycle $cycle: $HOST   ping=${PING_TIME}ms  dns=${DNS_LOOKUP_TIME}ms  curl_total=${TOTAL_TIME}s"
    sleep "$WAIT_BETWEEN_TARGETS"
  done

  echo "=== Cycle $cycle completed at $(date '+%Y-%m-%d %H:%M:%S'). Waiting $((WAIT_BETWEEN_CYCLES/60)) minutes... ==="
  ((cycle++))
  sleep "$WAIT_BETWEEN_CYCLES"
done
