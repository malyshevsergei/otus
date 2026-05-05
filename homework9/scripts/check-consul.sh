#!/usr/bin/env bash
# Consul cluster + DNS health check script.
# Run from any host that can reach the Consul server HTTP API and DNS port.
#
# Usage:
#   ./scripts/check-consul.sh <consul-server-ip>
#
# Exit codes: 0 = all checks passed, 1 = one or more checks failed.

set -euo pipefail

CONSUL_IP="${1:-127.0.0.1}"
CONSUL_HTTP="http://${CONSUL_IP}:8500"
CONSUL_DNS_IP="${CONSUL_IP}"
CONSUL_DNS_PORT="8600"
SERVICE_NAME="webapp"
REQUIRED_HEALTHY=1   # minimum healthy instances expected

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0

pass() { echo -e "${GREEN}[PASS]${NC} $1"; ((PASS++)) || true; }
fail() { echo -e "${RED}[FAIL]${NC} $1"; ((FAIL++)) || true; }
info() { echo -e "${YELLOW}[INFO]${NC} $1"; }

check_deps() {
  for cmd in curl dig jq; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "Required command not found: $cmd"
      exit 1
    fi
  done
}

# --- Check 1: Consul HTTP API is reachable ---
check_consul_api() {
  info "Checking Consul HTTP API at ${CONSUL_HTTP} ..."
  local status
  status=$(curl -sf --max-time 5 "${CONSUL_HTTP}/v1/status/leader" 2>/dev/null || true)
  if [[ -n "$status" && "$status" != '""' ]]; then
    pass "Consul HTTP API reachable. Leader: ${status}"
  else
    fail "Consul HTTP API not reachable or no leader elected at ${CONSUL_HTTP}"
  fi
}

# --- Check 2: All expected Consul nodes are alive ---
check_cluster_members() {
  info "Checking Consul cluster members ..."
  local members alive
  members=$(curl -sf --max-time 5 "${CONSUL_HTTP}/v1/agent/members" 2>/dev/null || echo '[]')
  alive=$(echo "$members" | jq '[.[] | select(.Status == 1)] | length')
  local total
  total=$(echo "$members" | jq 'length')

  if [[ "$alive" -ge 3 ]]; then
    pass "Consul cluster has ${alive}/${total} alive members (quorum OK)"
  else
    fail "Consul cluster has only ${alive}/${total} alive members (need >= 3 for quorum)"
  fi
}

# --- Check 3: webapp service has healthy instances ---
check_service_health() {
  info "Checking healthy instances of service '${SERVICE_NAME}' ..."
  local instances ips
  instances=$(curl -sf --max-time 5 \
    "${CONSUL_HTTP}/v1/health/service/${SERVICE_NAME}?passing=true" 2>/dev/null || echo '[]')
  local count
  count=$(echo "$instances" | jq 'length')
  ips=$(echo "$instances" | jq -r '.[].Service.Address')

  if [[ "$count" -ge "$REQUIRED_HEALTHY" ]]; then
    pass "Service '${SERVICE_NAME}': ${count} healthy instance(s)"
    info "  Healthy IPs: $(echo "$ips" | tr '\n' ' ')"
  else
    fail "Service '${SERVICE_NAME}': only ${count} healthy instance(s), expected >= ${REQUIRED_HEALTHY}"
  fi
}

# --- Check 4: DNS resolves webapp.service.consul ---
check_dns_resolution() {
  info "Querying DNS: ${SERVICE_NAME}.service.consul @${CONSUL_DNS_IP}:${CONSUL_DNS_PORT} ..."
  local records
  records=$(dig @"${CONSUL_DNS_IP}" -p "${CONSUL_DNS_PORT}" \
    "${SERVICE_NAME}.service.consul" +short 2>/dev/null || true)

  if [[ -n "$records" ]]; then
    pass "DNS resolved ${SERVICE_NAME}.service.consul to:"
    echo "$records" | while read -r ip; do info "  $ip"; done
  else
    fail "DNS returned no A records for ${SERVICE_NAME}.service.consul"
  fi
}

# --- Check 5: HTTP GET to each healthy instance ---
check_http_response() {
  info "Checking HTTP /health on each healthy instance ..."
  local instances ips
  instances=$(curl -sf --max-time 5 \
    "${CONSUL_HTTP}/v1/health/service/${SERVICE_NAME}?passing=true" 2>/dev/null || echo '[]')
  ips=$(echo "$instances" | jq -r '.[].Service.Address')

  if [[ -z "$ips" ]]; then
    fail "No healthy instances to HTTP-check"
    return
  fi

  while IFS= read -r ip; do
    local http_code
    http_code=$(curl -sf --max-time 5 -o /dev/null -w "%{http_code}" \
      "http://${ip}/health" 2>/dev/null || echo "000")
    if [[ "$http_code" == "200" ]]; then
      pass "HTTP /health on ${ip} returned 200"
    else
      fail "HTTP /health on ${ip} returned ${http_code} (expected 200)"
    fi
  done <<< "$ips"
}

# --- Check 6: DNS reflects failure after service becomes unhealthy ---
check_dns_failover_hint() {
  info "Failover check hint:"
  info "  To simulate failover, stop nginx on a web node:"
  info "    ssh ubuntu@<web-ip> 'sudo systemctl stop nginx'"
  info "  Then wait ~30s and re-run this script."
  info "  The failed node's IP should disappear from DNS responses."
}

# --- Main ---
echo "================================================"
echo " Consul Cluster Health Check"
echo " Target: ${CONSUL_HTTP}"
echo "================================================"
echo ""

check_deps
check_consul_api
check_cluster_members
check_service_health
check_dns_resolution
check_http_response
check_dns_failover_hint

echo ""
echo "================================================"
echo -e " Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}"
echo "================================================"

[[ "$FAIL" -eq 0 ]]
