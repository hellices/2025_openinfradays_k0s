# Azure VM 클러스터 + 베스천 호스트 배포 (azd + Bicep)

이 프로젝트는 Azure에 **6대의 워커 VM**과 **1대의 베스천 호스트**를 배포하고, SSH 키 기반 인증으로 베스천에서 다른 VM들로 안전하게 접속할 수 있도록 구성합니다.

## 🏗️ 아키텍처

- **베스천 VM (1대)**: 공용 IP 보유, SSH 키 + 비밀번호 인증 지원
- **워커 VM들 (6대)**: 사설 IP만, SSH 키 인증만 지원  
- **네트워크**: 단일 VNet (10.0.0.0/16) 내 단일 서브넷 (10.0.0.0/24)
- **보안**: SSH(22) 포트만 허용하는 NSG

## 📋 사전 준비

- Azure CLI 설치: https://docs.microsoft.com/ko-kr/cli/azure/install-azure-cli
- Azure Developer CLI(azd) 설치: https://learn.microsoft.com/ko-kr/azure/developer/azure-developer-cli/install-azd
- (VSCode 권장) 확장: [Azure Developer CLI Extension](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.azure-dev)

## 🚀 배포 방법

### 1. SSH 키 생성 및 환경 설정 (원클릭)
```bash
# SSH 키 생성 및 azd 환경변수 자동 등록
chmod +x generate-ssh-keys.sh
./generate-ssh-keys.sh
```

이 스크립트는 자동으로:
- SSH 키 쌍 생성
- azd 환경 초기화 (필요한 경우)
- VM_NAME 설정 (대화형)
- ADMIN_PASSWORD 설정 (대화형)
- SSH 키를 azd 환경변수로 등록
- 선택적으로 바로 배포 실행

### 2. 수동 설정 (필요한 경우)
```bash
# Azure 로그인
az login

# azd 환경 초기화 (최초 1회)
azd init

# 환경 변수 수동 설정
azd env set VM_NAME "myvm"
azd env set ADMIN_PASSWORD "YourSecurePassword123!"
azd env set SSH_PUBLIC_KEY "$(cat ./ssh-keys/vm-cluster-key.pub)"
azd env set SSH_PRIVATE_KEY "$(base64 -w 0 ./ssh-keys/vm-cluster-key)"
```

### 3. 배포 실행 (수동 설정한 경우)
```bash
azd up
```

## 💡 VSCode에서 Azure Developer CLI Extension 사용

1. VSCode 좌측 Extensions(확장) 메뉴 클릭
2. 'Azure Developer CLI' 검색 후 설치
3. 명령 팔레트(Ctrl+Shift+P)에서 `azd` 관련 명령 실행 가능

## 🔄 대안: Azure CLI를 사용한 배포

SSH 키 생성 후:
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

## 📋 사용 예시

### 전체 과정 (간단 버전)
```bash
# 1. 스크립트 실행 (SSH 키 생성 + 환경설정 + 선택적 배포)
./generate-ssh-keys.sh

# VM 이름 입력: myvm
# 비밀번호 입력: YourSecurePassword123!
# 바로 배포할지 선택: y

# 배포 완료 후 출력에서 공용 IP 확인
```

### 배포 완료 후 접속
```bash
# 1. 베스천 접속 (배포 출력에서 공용 IP 확인)
ssh azureuser@40.123.45.67  # 실제 공용 IP 사용

# 2. 베스천에서 SSH 키 확인
azureuser@myvm-bastion:~$ ls -la ~/.ssh/
# id_rsa, id_rsa.pub, authorized_keys, config 파일 확인

# 3. 워커 VM들로 접속
azureuser@myvm-bastion:~$ ssh azureuser@10.0.0.4  # myvm1
azureuser@myvm-bastion:~$ ssh azureuser@10.0.0.5  # myvm2
# ... 등등
```

## 🔐 SSH 접속 방법

### 베스천 호스트에 접속
```bash
# 배포 완료 후 출력된 공용 IP 사용
ssh azureuser@<BASTION_PUBLIC_IP>
```

### 베스천에서 워커 VM들로 접속
베스천 VM에 접속한 후:
```bash
# VM들의 사설 IP로 접속 (SSH 키 자동 사용)
ssh azureuser@10.0.0.4  # 첫 번째 워커 VM
ssh azureuser@10.0.0.5  # 두 번째 워커 VM
# ... 등등

# 또는 VM 이름으로 접속
ssh myvm1
ssh myvm2
# ... 등등
```

## ⚙️ 환경 변수

자동으로 설정되는 환경 변수:
- `VM_NAME`: VM 이름 패턴 접두어 (예: myvm)
- `ADMIN_PASSWORD`: 베스천 VM의 관리자 비밀번호
- `SSH_PUBLIC_KEY`: SSH 공개 키 내용
- `SSH_PRIVATE_KEY`: SSH 개인 키 내용 (base64 인코딩)

환경 변수 확인:
```bash
azd env get-values
```

## 📁 생성되는 리소스

- **Virtual Network**: `vnet-{VM_NAME}-krc-01` (10.0.0.0/16)
- **Subnet**: `default` (10.0.0.0/24)
- **Network Security Group**: `nsg-{VM_NAME}-krc-01` (SSH 22번만 허용)
- **베스천 VM**: `{VM_NAME}-bastion` (Ubuntu 20.04 LTS + 공용 IP)
- **워커 VM들**: `{VM_NAME}1` ~ `{VM_NAME}6` (Ubuntu 20.04 LTS + 사설 IP만)
- **공용 IP**: `{VM_NAME}-bastion-pip`

## 🛠️ 주요 azd 명령어

- **배포**: `azd up`
- **삭제**: `azd down`
- **상태 확인**: `azd show`
- **환경 변수 확인**: `azd env get-values`

## 🔒 보안 고려사항

1. **SSH 키 관리**: 개인 키는 안전하게 보관하고 공유하지 마세요
2. **베스천 호스트**: 모든 워커 VM 접근은 베스천을 통해서만 가능
3. **네트워크 격리**: 워커 VM들은 공용 IP가 없어 직접 접근 불가
4. **NSG 규칙**: SSH(22) 포트만 허용

## 🚨 문제 해결

### SSH 키 형식 오류
```
InvalidParameter: The value of parameter linuxConfiguration.ssh.publicKeys.keyData is invalid.
```
**해결방법**: 
1. SSH 키를 다시 생성: `./generate-ssh-keys.sh`
2. SSH 공개 키가 `ssh-rsa`로 시작하는지 확인: `cat ./ssh-keys/vm-cluster-key.pub`

### 공용 IP 제한 오류
```
IPv4BasicSkuPublicIpCountLimitReached: Cannot create more than 0 IPv4 Basic SKU public IP addresses
```
**해결방법**: 
- Bicep 템플릿이 Standard SKU를 사용하도록 이미 수정됨
- 기존 Basic SKU 공용 IP가 있다면 삭제 후 재시도

### 환경변수 확인
```bash
# SSH 키가 올바르게 설정되었는지 확인
azd env get SSH_PUBLIC_KEY
azd env get SSH_PRIVATE_KEY

# 모든 환경변수 확인
azd env get-values
```

## 🧹 리소스 정리

```bash
# azd를 사용한 정리
azd down

# 또는 Azure CLI로 리소스 그룹 삭제
az group delete --name <RESOURCE_GROUP_NAME> --yes --no-wait
```
