#!/usr/bin/env bash
# ==============================================================================
# Linux OS & Kernel Network Tuning Script for Distributed Load Generator Nodes
# ==============================================================================

set -euo pipefail

echo "==> Applying OS Kernel Network Optimizations for High-Throughput Load Testing..."

if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root or with sudo."
   exit 1
fi

sysctl -w net.ipv4.ip_local_port_range="1024 65535"
sysctl -w net.ipv4.tcp_tw_reuse=1
sysctl -w net.core.somaxconn=65535
sysctl -w net.core.netdev_max_backlog=65535
sysctl -w fs.file-max=2097152

cat << 'SYSCTL_EOF' > /etc/sysctl.d/99-resilientvote-loadgen.conf
net.ipv4.ip_local_port_range = 1024 65535
net.ipv4.tcp_tw_reuse = 1
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
fs.file-max = 2097152
SYSCTL_EOF

cat << 'LIMITS_EOF' > /etc/security/limits.d/99-nofile.conf
* soft nofile 65535
* hard nofile 65535
root soft nofile 65535
root hard nofile 65535
ubuntu soft nofile 65535
ubuntu hard nofile 65535
LIMITS_EOF

ulimit -n 65535

echo "==> Network optimizations applied successfully:"
sysctl net.ipv4.ip_local_port_range
sysctl net.ipv4.tcp_tw_reuse
sysctl net.core.somaxconn
echo "==> Open file descriptor limit: $(ulimit -n)"
