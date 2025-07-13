#!/bin/bash

# SSH 키 쌍 생성 및 azd 환경변수 등록 스크립트
# 이 스크립트는 배포 전에 실행하여 SSH 키를 생성하고 azd 환경변수로 등록합니다.

set -e  # 에러 발생 시 스크립트 종료

KEY_NAME="vm-cluster-key"
KEY_DIR="./ssh-keys"

echo "🔑 SSH 키 생성 및 Azure 환경 설정 스크립트"
echo "============================================"

# azd 명령 확인
if ! command -v azd &> /dev/null; then
    echo "❌ Azure Developer CLI(azd)가 설치되지 않았습니다."
    echo "다음 링크에서 설치해주세요: https://learn.microsoft.com/ko-kr/azure/developer/azure-developer-cli/install-azd"
    exit 1
fi

# Azure 로그인 확인
if ! az account show &> /dev/null; then
    echo "🔐 Azure에 로그인되지 않았습니다. 로그인을 진행합니다..."
    az login
fi

# azd 환경 초기화 확인
if ! azd env get-values &> /dev/null; then
    echo "🔧 azd 환경이 초기화되지 않았습니다. 초기화를 진행합니다..."
    azd init --no-prompt
fi

# VM_NAME 환경변수 설정 (없는 경우)
if ! azd env get VM_NAME &> /dev/null; then
    read -p "VM 이름 접두어를 입력하세요 (기본값: myvm): " vm_name
    vm_name=${vm_name:-myvm}
    azd env set VM_NAME "$vm_name"
    echo "✅ VM_NAME이 '$vm_name'로 설정되었습니다."
fi

# 관리자 비밀번호 설정 (없는 경우)
if ! azd env get ADMIN_PASSWORD &> /dev/null; then
    echo "베스천 VM의 관리자 비밀번호를 설정해주세요:"
    read -s -p "비밀번호: " admin_password
    echo ""
    azd env set ADMIN_PASSWORD "$admin_password"
    echo "✅ 관리자 비밀번호가 설정되었습니다."
fi

# SSH 키 디렉토리 생성
mkdir -p $KEY_DIR

# SSH 키 쌍 생성 (비밀번호 없이)
echo "🔑 SSH 키 쌍을 생성합니다..."
ssh-keygen -t rsa -b 4096 -f $KEY_DIR/$KEY_NAME -N "" -C "vm-cluster-access-key"

# SSH 키 검증
if [[ ! -f "$KEY_DIR/$KEY_NAME.pub" ]]; then
    echo "❌ SSH 공개 키 생성에 실패했습니다."
    exit 1
fi

# SSH 공개 키 형식 검증
SSH_PUBLIC_KEY_CONTENT=$(cat $KEY_DIR/$KEY_NAME.pub)
if [[ ! $SSH_PUBLIC_KEY_CONTENT =~ ^ssh-rsa ]]; then
    echo "❌ SSH 공개 키 형식이 올바르지 않습니다."
    exit 1
fi

echo "SSH 키 생성 완료:"
echo "- 개인 키: $KEY_DIR/$KEY_NAME"
echo "- 공개 키: $KEY_DIR/$KEY_NAME.pub"
echo ""

# azd 환경변수로 자동 등록 (comment 제거)
echo "azd 환경변수로 SSH 키 등록 중..."
# Azure는 SSH 키의 comment 부분을 허용하지 않으므로 제거
PUBLIC_KEY_ONLY=$(cat $KEY_DIR/$KEY_NAME.pub | cut -d' ' -f1,2)
azd env set SSH_PUBLIC_KEY "$PUBLIC_KEY_ONLY"
azd env set SSH_PRIVATE_KEY "$(base64 -w 0 $KEY_DIR/$KEY_NAME)"

echo "✅ SSH 키가 azd 환경변수로 등록되었습니다!"
echo ""
echo "📋 현재 등록된 환경변수 확인:"
azd env get-values
echo ""
echo "🚀 배포 옵션:"
echo "1. 바로 배포: azd up"
echo "2. 환경변수 확인: azd env get-values"
echo "3. 환경변수 수정: azd env set <KEY> <VALUE>"
echo ""
read -p "지금 바로 배포하시겠습니까? (y/N): " deploy_now
if [[ $deploy_now =~ ^[Yy]$ ]]; then
    echo "🚀 배포를 시작합니다..."
    azd up
else
    echo "📝 준비가 완료되었습니다. 원하는 시점에 'azd up' 명령을 실행하세요."
fi
echo ""
echo "=== 수동 등록이 필요한 경우 아래 명령 사용 ==="
echo "azd env set SSH_PUBLIC_KEY \"$(cat $KEY_DIR/$KEY_NAME.pub)\""
echo "azd env set SSH_PRIVATE_KEY \"$(base64 -w 0 $KEY_DIR/$KEY_NAME)\""
