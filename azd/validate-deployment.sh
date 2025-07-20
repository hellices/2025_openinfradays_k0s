#!/bin/bash

# 배포 전 검증 스크립트
# Pre-deployment validation script

set -e

echo "=== OpenInfraDays K0s VM Deployment Validation ==="
echo

# 현재 디렉토리 확인
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "Working directory: $SCRIPT_DIR"

# 필수 파일 확인
echo "Checking required files..."
REQUIRED_FILES=(".env" "azure.yaml" "infra/main.bicep")

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$SCRIPT_DIR/$file" ]; then
        echo "✓ $file found"
    else
        echo "✗ $file missing"
        exit 1
    fi
done

# .env 파일 내용 확인
echo
echo "Checking .env configuration..."
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
    
    # 필수 변수 확인
    REQUIRED_VARS=("VM_NAME" "ADMIN_PASSWORD" "AZURE_RESOURCE_GROUP")
    
    for var in "${REQUIRED_VARS[@]}"; do
        if [ -n "${!var}" ]; then
            echo "✓ $var is set"
        else
            echo "✗ $var is not set"
            exit 1
        fi
    done
    
    # BASTION_PASSWORD 선택사항 확인
    if [ -n "$BASTION_PASSWORD" ]; then
        echo "✓ BASTION_PASSWORD is set (will use specified password)"
    else
        echo "✓ BASTION_PASSWORD is not set (will prompt during deployment)"
    fi
    
    # SSH 키 확인
    if [ -n "$SSH_PUBLIC_KEY" ]; then
        echo "✓ SSH_PUBLIC_KEY is configured (SSH key authentication will be used)"
        echo "  Key preview: ${SSH_PUBLIC_KEY:0:50}..."
    else
        echo "✓ SSH_PUBLIC_KEY is empty (password authentication will be used)"
    fi
else
    echo "✗ .env file not found"
    exit 1
fi

# Bicep 템플릿 구문 검사
echo
echo "Validating Bicep template syntax..."
if command -v az &> /dev/null; then
    if az bicep build --file "$SCRIPT_DIR/infra/main.bicep" > /dev/null 2>&1; then
        echo "✓ Bicep template syntax is valid"
    else
        echo "✗ Bicep template has syntax errors"
        az bicep build --file "$SCRIPT_DIR/infra/main.bicep"
        exit 1
    fi
else
    echo "⚠ Azure CLI not found, skipping Bicep validation"
fi

# azd 설정 확인
echo
echo "Checking azd configuration..."
if [ -f "$SCRIPT_DIR/azure.yaml" ]; then
    echo "✓ azure.yaml found"
    
    # azure.yaml 내용 간단 검증
    if grep -q "vmName: \${VM_NAME}" "$SCRIPT_DIR/azure.yaml"; then
        echo "✓ VM_NAME parameter configured"
    else
        echo "✗ VM_NAME parameter not found in azure.yaml"
        exit 1
    fi
    
    if grep -q "sshPublicKey: \${SSH_PUBLIC_KEY}" "$SCRIPT_DIR/azure.yaml"; then
        echo "✓ SSH_PUBLIC_KEY parameter configured"
    else
        echo "✗ SSH_PUBLIC_KEY parameter not found in azure.yaml"
        exit 1
    fi
else
    echo "✗ azure.yaml not found"
    exit 1
fi

# 예상 리소스 정보 표시
echo
echo "=== Deployment Preview ==="
echo "Resource Group: $AZURE_RESOURCE_GROUP"
echo "VM Name Pattern: $VM_NAME"
echo "Worker VMs: ${VM_NAME}1, ${VM_NAME}2, ${VM_NAME}3, ${VM_NAME}4, ${VM_NAME}5, ${VM_NAME}6"
echo "Bastion VM: ${VM_NAME}-bastion"
echo "Authentication: $([ -n "$SSH_PUBLIC_KEY" ] && echo "SSH Key" || echo "Password")"
echo

echo "=== Validation Complete ==="
echo "✓ All checks passed! Ready for deployment with 'azd up'"

# 배포 명령어 안내
echo
echo "Next steps:"
echo "1. (Optional) Generate SSH keys: ./setup-ssh.sh"
echo "2. Deploy: azd up"
echo "3. After deployment, connect to bastion VM and use aliases: vm1, vm2, vm3, vm4, vm5, vm6"