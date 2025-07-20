#!/bin/bash

# SSH 키 설정 헬퍼 스크립트
# This script helps set up SSH keys for the VM deployment

set -e

echo "=== OpenInfraDays K0s VM Deployment SSH Setup ==="
echo

# SSH 키 경로 설정
SSH_KEY_PATH="$HOME/.ssh/openinfradays"
SSH_PUBLIC_KEY_PATH="${SSH_KEY_PATH}.pub"

# SSH 키 생성 여부 확인
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "SSH 키를 생성합니다..."
    ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -C "openinfradays@$(hostname)" -N ""
    echo "SSH 키가 생성되었습니다: $SSH_KEY_PATH"
else
    echo "기존 SSH 키를 사용합니다: $SSH_KEY_PATH"
fi

# 공개키 내용 읽기
if [ -f "$SSH_PUBLIC_KEY_PATH" ]; then
    SSH_PUBLIC_KEY_CONTENT=$(cat "$SSH_PUBLIC_KEY_PATH")
    echo
    echo "SSH 공개키 내용:"
    echo "$SSH_PUBLIC_KEY_CONTENT"
    echo
    
    # .env 파일 업데이트
    ENV_FILE="$(dirname "$0")/.env"
    if [ -f "$ENV_FILE" ]; then
        echo ".env 파일을 업데이트합니다..."
        
        # SSH_PUBLIC_KEY 라인이 있는지 확인하고 업데이트
        if grep -q "^SSH_PUBLIC_KEY=" "$ENV_FILE"; then
            # 기존 라인을 주석 처리하고 새로운 라인 추가
            sed -i.bak "s|^SSH_PUBLIC_KEY=.*|SSH_PUBLIC_KEY=\"$SSH_PUBLIC_KEY_CONTENT\"|" "$ENV_FILE"
        elif grep -q "^# SSH_PUBLIC_KEY=" "$ENV_FILE"; then
            # 주석 처리된 라인을 활성화하고 업데이트
            sed -i.bak "s|^# SSH_PUBLIC_KEY=.*|SSH_PUBLIC_KEY=\"$SSH_PUBLIC_KEY_CONTENT\"|" "$ENV_FILE"
        else
            # 새로운 라인 추가
            echo "SSH_PUBLIC_KEY=\"$SSH_PUBLIC_KEY_CONTENT\"" >> "$ENV_FILE"
        fi
        
        echo ".env 파일이 업데이트되었습니다."
    else
        echo "주의: .env 파일을 찾을 수 없습니다. 수동으로 SSH_PUBLIC_KEY를 설정해주세요."
    fi
    
    echo
    echo "=== 배포 준비 완료 ==="
    echo "SSH 키 인증이 설정되었습니다. 'azd up' 명령으로 배포를 시작할 수 있습니다."
    echo "SSH 키를 사용하므로 패스워드 프롬프트는 나타나지 않습니다."
    echo
    echo "배포 후 Bastion VM에 접속하려면:"
    echo "ssh -i $SSH_KEY_PATH azureuser@<bastion-public-ip>"
    echo
else
    echo "오류: SSH 공개키 파일을 찾을 수 없습니다: $SSH_PUBLIC_KEY_PATH"
    exit 1
fi