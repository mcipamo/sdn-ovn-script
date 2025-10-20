# OpenShift SDN → OVN Migration - Runtime Validation Script

This repository contains a Bash-based validation tool designed to **monitor and verify the OpenShift SDN to OVN-Kubernetes migration** process in real-time.  
It helps Support Engineers, Customers, and Platform Administrators validate each step of the migration, identify blocked states, and ensure operator reconciliation during and after the transition.

---

## Overview

During the SDN → OVN migration process, multiple components (MachineConfigPools, Network Operator, DaemonSets, and nodes) must transition in sync.  
This script continuously checks:

- Migration mode and status (`spec.migration.*`)
- Network operator health and reconciliation
- MCPs update and degraded status
- Pod health for key networking namespaces
- Network operator logs (real-time error parsing)
- Node CNI annotations (`ovn-kubernetes`)
- DNS pod status

---

## Usage

### Prerequisites
- **OpenShift CLI (`oc`)** configured and authenticated.
- Cluster-admin or equivalent permissions.

### Execution Modes

#### Single Validation Run
```
./sdn-ovn-check.sh
```

#### Continuous Monitoring (Recommended)
```
./sdn-ovn-check.sh --watch
```
Runs all validations continuously every 30 seconds (default interval).  
Press `Ctrl + C` to stop the loop.

#### Custom Interval Example
You can customize the refresh interval using `--interval=<seconds>`:
```
./sdn-ovn-check.sh --watch --interval=60
```
This example runs all validations every 60 seconds.

---

## Example Output (Visual Preview)

```
 SDN → OVN Migration Runtime Validation - Fri Oct 18 14:30:02 UTC 2025

[1] Migration configuration
Mode: Live | Migration Type: OpenShiftSDN | Current Type: OVNKubernetes
Migration in progress or recently completed (Live → OVNKubernetes)

[2] Network operator conditions
NAME      AVAILABLE   PROGRESSING   DEGRADED   VERSION
network   True        False         False      4.16.12

[3] MachineConfigPools status
NAME      UPDATED   READY   DEGRADED   UPDATING
master    3         3       0          False
worker    6         6       0          False

[4] Pods status for networking components
Namespace: openshift-ovn-kubernetes
All pods healthy 

Namespace: openshift-sdn
All pods terminated as expected 

[5] Recent network-operator log errors
No critical errors found 

[6] Node CNI annotations (SDN vs OVN)
ip-10-0-12-45.ec2.internal => {"ipv4":"10.0.12.45"}
ip-10-0-16-87.ec2.internal => {"ipv4":"10.0.16.87"}

[7] Operator reconciliation status
Operator is in sync (generation 18 == observed 18)

[8] OVN rollout status
NAME                 DESIRED   CURRENT   READY
ovnkube-node         6         6         6
ovnkube-master       3         3         3

[9] DNS sanity check
All DNS pods healthy 

Validation completed at Fri Oct 18 14:31:15 UTC 2025
To collect logs: oc adm must-gather -- /usr/bin/gather_network_logs
```

---

## 📘 Author
**Milton Cipamocha** – SME, Red Hat Managed Cloud Services  
