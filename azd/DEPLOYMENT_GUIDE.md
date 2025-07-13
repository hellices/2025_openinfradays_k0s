# VM 클러스터 + 베스천 호스트 배포 가이드

이 프로젝트는 Azure에 6대의 VM과 1대의 베스천 호스트를 배포하고, SSH 키 기반 인증으로 베스천에서 다른 VM들로 안전하게 접속할 수 있도록 구성합니다.

## 배포 전 준비

### 1. SSH 키 생성
```bash
# SSH 키 생성 스크립트 실행
chmod +x generate-ssh-keys.sh
./generate-ssh-keys.sh
```

이 스크립트는 다음을 생성합니다:
- `./ssh-keys/vm-cluster-key` (개인 키)
- `./ssh-keys/vm-cluster-key.pub` (공개 키)

### 2. 환경 변수 설정
```bash
export VM_NAME="myvm"
export SSH_PUBLIC_KEY="$(cat ./ssh-keys/vm-cluster-key.pub)"
export SSH_PRIVATE_KEY="$(base64 -w 0 ./ssh-keys/vm-cluster-key)"
```

## 배포 실행

### Azure Developer CLI를 사용한 배포
```bash
# 로그인
azd auth login

# 초기화 (필요한 경우)
azd init

# 환경 설정
azd env set VM_NAME "myvm"
azd env set SSH_PUBLIC_KEY "$(cat ./ssh-keys/vm-cluster-key.pub)"
azd env set SSH_PRIVATE_KEY "$(base64 -w 0 ./ssh-keys/vm-cluster-key)"

# 관리자 비밀번호 설정 (베스천 VM용)
azd env set  "YourSecurePassword123!"

# 배포
azd up
```

### Azure CLI를 사용한 배포
```bash
# 리소스 그룹 생성
az group create --name rg-vm-cluster --location "Korea Central"

# 배포 실행
az deployment group create \
  --resource-group rg-vm-cluster \
  --template-file ./infra/main.bicep \
  --parameters vmName="myvm" \
               adminPassword="YourSecurePassword123!" \
               sshPublicKey="$(cat ./ssh-keys/vm-cluster-key.pub)" \
               sshPrivateKey="$(base64 -w 0 ./ssh-keys/vm-cluster-key)"
```

## 배포 후 사용법

### 1. 베스천 호스트에 접속
```bash
# 베스천 VM의 공용 IP로 접속
ssh azureuser@<BASTION_PUBLIC_IP>
```

### 2. 베스천에서 다른 VM들로 접속
베스천 VM에 접속한 후:
```bash
# VM들의 사설 IP로 접속 (SSH 키 자동 사용)
ssh azureuser@10.0.0.4  # 첫 번째 VM
ssh azureuser@10.0.0.5  # 두 번째 VM
# ... 등등

# 또는 VM 이름으로 접속 (DNS 해석이 되는 경우)
ssh myvm1
ssh myvm2
# ... 등등
```

## 아키텍처 개요

- **베스천 VM**: 공용 IP 보유, SSH 키 + 비밀번호 인증 지원
- **워커 VM들**: 사설 IP만, SSH 키 인증만 지원
- **네트워크**: 단일 VNet (10.0.0.0/16) 내 단일 서브넷 (10.0.0.0/24)
- **보안**: SSH(22) 포트만 허용하는 NSG

## 보안 고려사항

1. **SSH 키 관리**: 개인 키는 안전하게 보관하고 공유하지 마세요.
2. **베스천 호스트**: 모든 VM 접근은 베스천을 통해서만 가능합니다.
3. **네트워크 격리**: 워커 VM들은 공용 IP가 없어 직접 접근이 불가능합니다.

## 정리

```bash
# 리소스 그룹 삭제로 모든 리소스 정리
az group delete --name rg-vm-cluster --yes --no-wait

# 또는 azd를 사용한 경우
azd down
```
