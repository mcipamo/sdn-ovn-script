#!/bin/bash
# ----------------------------------------------------------------------
# OpenShift SDN → OVN Migration - Runtime Validation Script (with --watch)
# Author: Milton Cipamocha - SME - Red Hat, Managed Cloud Services
# ----------------------------------------------------------------------

set -euo pipefail

INTERVAL=30
WATCH_MODE=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to print section headers
print_header() {
  echo -e "\n${YELLOW}[$1] $2${NC}"
}

# Ensure required commands are available
command_exists() {
  if ! command -v oc >/dev/null 2>&1; then
    echo "oc CLI not found in PATH. Please install/configure oc and try again." >&2
    exit 2
  fi
}

# Function that runs all validation checks once
run_checks() {
  clear
  echo -e "\n ${YELLOW}SDN → OVN Migration Runtime Validation - $(date)${NC}\n"

  # Migration Mode Check
  print_header "1" "Migration configuration"
  MIG_MODE=$(oc get network.operator cluster -o jsonpath='{.spec.migration.mode}' 2>/dev/null)
  MIG_NET=$(oc get network.operator cluster -o jsonpath='{.spec.migration.networkType}' 2>/dev/null)
  NET_TYPE=$(oc get network.operator cluster -o jsonpath='{.spec.defaultNetwork.type}' 2>/dev/null)
  echo "Mode: ${MIG_MODE} | Migration Type: ${MIG_NET} | Current Type: ${NET_TYPE}"
  if [[ "$MIG_MODE" == "Live" && "$NET_TYPE" == "OVNKubernetes" ]]; then
    echo -e "${GREEN} Migration in progress or recently completed (Live → OVNKubernetes).${NC}"
  elif [[ "$MIG_NET" == "OpenShiftSDN" && "$NET_TYPE" == "OVNKubernetes" ]]; then
    echo -e "${YELLOW} Migration defined but not yet applied.${NC}"
  else
    echo -e "${RED} Migration not properly configured.${NC}"
  fi

  # Network Operator Health
  print_header "2" "Network operator conditions"
  oc get co network -o 'custom-columns=NAME:.metadata.name,AVAILABLE:.status.conditions[?(@.type=="Available")].status,PROGRESSING:.status.conditions[?(@.type=="Progressing")].status,DEGRADED:.status.conditions[?(@.type=="Degraded")].status,VERSION:.status.versions[0].version'

  # MCP status
  print_header "3" "MachineConfigPools status"
  oc get mcp -o 'custom-columns=NAME:.metadata.name,UPDATED:.status.updatedMachineCount,READY:.status.readyMachineCount,DEGRADED:.status.degradedMachineCount,UPDATING:.status.conditions[?(@.type=="Updating")].status'

  # Pods status
  print_header "4" "Pods status for networking components"
  for ns in openshift-network-operator openshift-ovn-kubernetes openshift-sdn openshift-cloud-network-config-controller; do
    echo -e "\nNamespace: ${ns}"
    oc get pods -n "$ns" --no-headers | grep -vE '(Running|Completed)' || echo "All pods healthy"
  done

  #  Operator Logs
  print_header "5" "Recent network-operator log errors"
  oc logs -n openshift-network-operator deploy/network-operator --tail=20 | grep -Ei "error|fail|migration" || echo "No critical errors found."

  # Node Annotations
  print_header "6" "Node CNI annotations (SDN vs OVN)"
  oc get nodes -o jsonpath='{range .items[*]}{.metadata.name}{" => "}{.metadata.annotations.k8s\.ovn\.org/node-primary-ifaddr}{"\n"}{end}' | sed '/=> $/d' || echo "No OVN annotations yet (still SDN)."

  #  Generation Sync
  print_header "7" "Operator reconciliation status"
  GEN=$(oc get network.operator cluster -o jsonpath='{.metadata.generation}')
  OBS=$(oc get network.operator cluster -o jsonpath='{.status.observedGeneration}')
  if [[ "$GEN" == "$OBS" ]]; then
    echo -e "${GREEN} Operator is in sync (generation $GEN == observed $OBS).${NC}"
  else
    echo -e "${RED} Operator not reconciled (generation $GEN vs observed $OBS).${NC}"
  fi

  # OVN rollout
  print_header "8" "OVN rollout status"
  oc get ds -n openshift-ovn-kubernetes || echo "OVN DaemonSets not found."
  oc get pods -n openshift-ovn-kubernetes -o wide | grep -i ovnkube-node || echo "No OVN node pods found."

  #  DNS check
  print_header "9" "DNS sanity check"
  oc get pods -n openshift-dns --no-headers | grep -vE '(Running|Completed)' || echo "All DNS pods healthy"

  echo -e "\n${GREEN} Validation completed at $(date).${NC}"
  echo -e "To collect logs: oc adm must-gather -- /usr/bin/gather_network_logs\n"
}

# ------------------------------
# Argument parsing
# ------------------------------
while [ "$#" -gt 0 ]; do
  case "$1" in
    --watch)
      WATCH_MODE=true
      shift
      ;;
    --interval=*)
      INTERVAL="${1#*=}"
      shift
      ;;
    *)
      shift
      ;;
  esac
done

# Validate interval is a positive integer
if ! [[ "$INTERVAL" =~ ^[0-9]+$ ]] || [ "$INTERVAL" -le 0 ]; then
  echo "Invalid --interval value: $INTERVAL. Must be a positive integer." >&2
  exit 3
fi

# ------------------------------
# Runtime execution
# ------------------------------
command_exists

if [ "$WATCH_MODE" = true ]; then
  echo -e "${YELLOW}Entering watch mode (every ${INTERVAL}s)... Press Ctrl+C to stop.${NC}"
  while true; do
    run_checks
    echo -e "\n${YELLOW}Sleeping for ${INTERVAL}s...${NC}"
    sleep $INTERVAL
  done
else
  run_checks
fi

