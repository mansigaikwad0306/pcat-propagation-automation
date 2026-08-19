#!/bin/bash
# PROD Post-Propagation Automation
# Usage:
#   bash propagation_post_prod.sh <WORK_ID>
#   bash propagation_post_prod.sh --versions-only
#
# Set before run (do NOT commit real passwords):
#   export SSH_PASS='your-jumpbox-ssh-password'
#   export TEAM_EMAIL='team@company.com'

WORK_ID=""
VERSIONS_ONLY=0
TEAM_EMAIL="${TEAM_EMAIL:-your-team@company.com}"

PORT=8001
PAGE="getResellerInfo.jsp"
CURL_TIMEOUT=30
RESELLER_TIMEOUT=10

SSH_PASS="${SSH_PASS:-}"
SSH_USER="${SSH_USER:-root}"
SSH_TIMEOUT=15

SAPI_IPS=(
  "10.140.33.140"
  "10.140.33.141"
  "10.140.33.142"
  "10.140.33.143"
)

OMSAPI_IPS=(
  "10.140.33.144"
  "10.140.33.145"
  "10.140.33.192"
  "10.140.33.193"
)

TSP_SERVERS=(
  "gy-slu1|10.140.1.19"
  "gy-slu2|10.140.1.20"
  "gy-slu3|10.140.1.21"
  "gy-slu4|10.140.1.22"
  "gy-slu5|10.140.1.23"
  "gy-slu6|10.140.1.24"
  "gy-slu7|10.140.1.25"
  "gy-slu8|10.140.1.26"
  "gy-dslu1|10.140.1.31"
  "gy-dslu2|10.140.1.32"
  "gy-dslu3|10.140.1.33"
  "gy-notif1|10.140.1.15"
  "gy-notif2|10.140.1.16"
)

if [ "$1" = "--versions-only" ]; then
  VERSIONS_ONLY=1
elif [ -n "$1" ]; then
  WORK_ID="$1"
fi

fetch_reseller_info() {
  local ip="$1"
  unset c
  c=()
  mapfile -t c < <(curl -s --connect-timeout "$RESELLER_TIMEOUT" \
    "http://${ip}:${PORT}/sapi/${PAGE}" 2>/dev/null | \
    grep -oE '<(td|th)[^>]*>[^<]*</(td|th)>' | \
    sed 's/<[^>]*>//g' | head -14)
}

print_reseller_table() {
  local title="$1"
  local ip_label="$2"
  shift 2
  local ips=("$@")

  echo ""
  echo "${title} - $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""
  printf "| %-16s | %-14s | %-8s | %-8s | %-22s | %-14s | %-6s | %-6s |\n" \
    "$ip_label" "Reseller Name" "Res Ver" "Svc Ver" "Active Date" "Inactive Date" "Major" "Minor"
  printf "|%-18s|%-16s|%-10s|%-10s|%-24s|%-16s|%-8s|%-8s|\n" \
    "------------------" "----------------" "----------" "----------" "------------------------" "----------------" "--------" "--------"

  for ip in "${ips[@]}"; do
    fetch_reseller_info "$ip"
    if [ ${#c[@]} -lt 14 ]; then
      printf "| %-16s | %-14s | %-8s | %-8s | %-22s | %-14s | %-6s | %-6s |\n" \
        "$ip" "UNREACHABLE" "-" "-" "-" "-" "-" "-"
      continue
    fi
    local inactive="${c[11]:--}"
    [ -z "${c[11]}" ] && inactive="-"
    printf "| %-16s | %-14s | %-8s | %-8s | %-22s | %-14s | %-6s | %-6s |\n" \
      "$ip" "${c[7]}" "${c[8]}" "${c[9]}" "${c[10]}" "$inactive" "${c[12]}" "${c[13]}"
  done
  echo ""
}

print_tsp_table() {
  if ! command -v sshpass &> /dev/null; then
    echo ""
    echo "TSP Version Check - SKIPPED (install: yum install sshpass -y)"
    echo ""
    return 1
  fi

  if [ -z "$SSH_PASS" ]; then
    echo ""
    echo "TSP Version Check - SKIPPED (set SSH_PASS environment variable)"
    echo ""
    return 1
  fi

  echo ""
  echo "TSP Version Check - $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""
  printf "%-12s %-15s %-40s\n" "SHORT NAME" "IP" "TSP VERSION"
  printf "%-12s %-15s %-40s\n" "----------" "---------------" "----------------------------------------"

  for entry in "${TSP_SERVERS[@]}"; do
    IFS='|' read -r SHORT IP <<< "$entry"
    RAW=$(sshpass -p "$SSH_PASS" ssh -o ConnectTimeout=$SSH_TIMEOUT \
      -o StrictHostKeyChecking=no ${SSH_USER}@${IP} \
      "su - sncpuser -c 'echo \"tsp,dump-table=online_v_list;\" | omd TSP 2>&1'" 2>&1)

    if echo "$RAW" | grep -qiE "permission denied|connection refused|timed out|no route|failed|error"; then
      VERSION="FAILED"
    else
      VERSION=$(echo "$RAW" | grep -iE "version|online" | tail -1 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      [ -z "$VERSION" ] && VERSION=$(echo "$RAW" | tail -3 | tr '\n' ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      [ -z "$VERSION" ] && VERSION="NO OUTPUT"
    fi
    printf "%-12s %-15s %-40s\n" "$SHORT" "$IP" "$VERSION"
  done
  echo ""
}

run_version_report() {
  echo "============================================================"
  echo "Version Check - TSP | SAPI | OMSAPI"
  echo "Started: $(date '+%Y-%m-%d %H:%M:%S')"
  echo "============================================================"
  print_tsp_table
  print_reseller_table "SAPI Reseller Version Check" "SAPI IP" "${SAPI_IPS[@]}"
  print_reseller_table "OMSAPI Reseller Version Check" "OMSAPI IP" "${OMSAPI_IPS[@]}"
  echo "============================================================"
  echo "Version check complete - $(date '+%Y-%m-%d %H:%M:%S')"
  echo "============================================================"
}

step1_check_propagation() {
  echo ""
  echo "STEP 1: Check Propagation SUCCESS in PCAT DB"
  echo ""

  if [ -z "$WORK_ID" ]; then
    read -rp "Enter propagation WORK_ID: " WORK_ID
  fi

  echo "Run in PCAT DB:"
  echo "  select work_id, status_id from dp_work where work_id = ${WORK_ID};"
  echo "  (Status_Id = 80 means SUCCESS)"
  echo ""

  read -rp "Is propagation SUCCESS for work_id ${WORK_ID}? (yes/no): " CONFIRM
  if [ "$CONFIRM" != "yes" ]; then
    echo "STOPPED."
    exit 1
  fi
}

step2_reload_sapi_cache() {
  echo ""
  echo "STEP 2: Reload SAPI Cache"
  echo ""
  for ip in "${SAPI_IPS[@]}"; do
    resp=$(curl -s --connect-timeout "$CURL_TIMEOUT" \
      "http://${ip}:${PORT}/sapi/reloadAllCacheData.jsp" 2>&1)
    if [ -z "$resp" ]; then
      echo "$ip - FAILED"
    else
      echo "$ip - OK"
    fi
  done
  echo ""
}

if [ "$VERSIONS_ONLY" -eq 1 ]; then
  run_version_report
  exit 0
fi

echo "PROD Post-Propagation - $(date)"
step1_check_propagation
step2_reload_sapi_cache
run_version_report
echo "ALL STEPS COMPLETE"
