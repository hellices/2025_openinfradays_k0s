#!/bin/bash

# SSH 연결 테스트 스크립트
# This script demonstrates how to test SSH connectivity from bastion to worker VMs
# Run this script ON THE BASTION VM after deployment

set -e

echo "=== SSH Connectivity Test ==="
echo "This script tests SSH connectivity from bastion to worker VMs"
echo

# Check if SSH key exists
if [ ! -f "$HOME/.ssh/bastion_key" ]; then
    echo "❌ SSH key not found at $HOME/.ssh/bastion_key"
    echo "Make sure the deployment completed successfully"
    exit 1
fi

echo "✓ SSH key found: $HOME/.ssh/bastion_key"

# Check SSH config
if [ ! -f "$HOME/.ssh/config" ]; then
    echo "❌ SSH config not found at $HOME/.ssh/config"
    exit 1
fi

echo "✓ SSH config found: $HOME/.ssh/config"

# Test connectivity to each VM
echo
echo "Testing SSH connectivity to worker VMs..."

for i in {1..6}; do
    echo -n "Testing vm$i (10.0.0.$((i+3))): "
    
    # Test SSH connection with timeout
    if timeout 10 ssh -o ConnectTimeout=5 -o BatchMode=yes vm$i "echo 'Connection successful'" 2>/dev/null; then
        echo "✓ Connected"
    else
        echo "❌ Failed"
    fi
done

echo
echo "=== Connectivity Test Complete ==="
echo
echo "Usage examples:"
echo "  vm1          # Connect to first worker VM"
echo "  ssh vm2      # Connect to second worker VM" 
echo "  ssh 10.0.0.6 -i ~/.ssh/bastion_key  # Direct SSH to third worker VM"