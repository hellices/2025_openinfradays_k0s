# Azure VM 배포 예제 (azd + Bicep)

<details>
<summary><strong>Azure Developer CLI(azd)로 Ubuntu VM 6대 + Bastion VM 1대 배포하기</strong></summary>

## 사전 준비
- Azure CLI 설치: https://docs.microsoft.com/ko-kr/cli/azure/install-azure-cli
- Azure Developer CLI(azd) 설치: https://learn.microsoft.com/ko-kr/azure/developer/azure-developer-cli/install-azd
- (VSCode 권장) 확장: [Azure Developer CLI Extension](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.azure-dev)

## 배포 방법

1. Azure 로그인
   ```bash
   az login
   ```
2. 리소스 그룹 생성 (예시)
   ```bash
   az group create --name rg-openinfradays-krc-01 --location koreacentral
   ```
3. (선택사항) SSH 키 생성 및 설정
   ```bash
   ./setup-ssh.sh
   ```
4. 배포 전 검증
   ```bash
   ./validate-deployment.sh
   ```
5. azd 프로젝트 초기화 (최초 1회)
   ```bash
   azd init
   # 이미 레포지토리에 azd/azure.yaml이 포함되어 있어 추가 프롬프트는 최소화됩니다.
   ```
6. 배포
   ```bash
   azd up
   ```

## 아키텍처
- **Bastion VM**: Public IP를 가진 점프 서버 (SSH 접근 가능)
- **Worker VMs**: 6대의 Ubuntu VM (Private IP만, Bastion을 통해서만 접근 가능)
- **네트워크**: 동일한 VNet 내에서 통신
- **인증**: SSH 키 또는 패스워드 인증 지원

## Bastion VM 사용법
1. Bastion VM에 SSH 접속
   ```bash
   ssh azureuser@<bastion-public-ip>
   ```
   또는 SSH 키 사용시:
   ```bash
   ssh -i ~/.ssh/openinfradays azureuser@<bastion-public-ip>
   ```

2. Bastion에서 내부 VM들에 접속 (alias 사용)
   ```bash
   vm1  # openinfradays1 VM 접속
   vm2  # openinfradays2 VM 접속
   vm3  # openinfradays3 VM 접속
   vm4  # openinfradays4 VM 접속
   vm5  # openinfradays5 VM 접속
   vm6  # openinfradays6 VM 접속
   ```

3. SSH 연결 테스트 (배포 후 bastion VM에서 실행)
   ```bash
   ./test-ssh-connectivity.sh
   ```

## SSH 키 인증 동작 방식
- **외부 → Bastion**: 사용자의 SSH 키 (`~/.ssh/openinfradays`) 사용
- **Bastion → Worker VMs**: Bastion에서 자동 생성된 SSH 키 (`~/.ssh/bastion_key`) 사용
- 배포 중 Bastion VM이 자동으로 SSH 키를 생성하고 모든 Worker VM에 공개키를 배포
- SSH config에 각 VM별 IdentityFile이 설정되어 있어 별도 키 지정 불필요

## 옵션/파라미터
- **VM_NAME**: VM 이름 패턴 접두어 (예: openinfradays)
- **ADMIN_PASSWORD**: Ubuntu VM의 관리자 비밀번호 (SSH 키 미사용시)
  - 6-72자, 대문자/소문자/숫자/특수문자 중 최소 3가지 조합 필요
- **BASTION_PASSWORD**: Bastion VM의 관리자 비밀번호 (선택사항)
  - 설정하지 않으면 `azd up` 시 프롬프트로 입력받음
  - SSH 키 사용시 불필요
  - 6-72자, 대문자/소문자/숫자/특수문자 중 최소 3가지 조합 필요
- **SSH_PUBLIC_KEY**: SSH 공개키 (설정시 SSH 키 인증 사용, 비어있으면 패스워드 인증)

## 주요 azd 명령어
- 배포: `azd up`
- 삭제: `azd down`
- 상태 확인: `azd show`

## 헬퍼 스크립트
- **setup-ssh.sh**: SSH 키 생성 및 .env 파일 자동 설정
- **validate-deployment.sh**: 배포 전 설정 검증
- **test-ssh-connectivity.sh**: SSH 연결 테스트 (배포 후 bastion VM에서 실행)

## 환경 변수(.env) 설정
```env
ADMIN_PASSWORD=OpenInfraDays2025!        # Azure 복잡도 요구사항 충족 필요
# BASTION_PASSWORD=                      # 설정하지 않으면 azd up 시 프롬프트로 입력
VM_NAME=openinfradays
AZURE_RESOURCE_GROUP=rg-openinfradays-krc-01
SSH_PUBLIC_KEY=ssh-rsa AAAAB3... # SSH 키 사용시 공개키 내용 (선택사항)
```

## 배포 방법

### 1. 패스워드 인증으로 배포 (기본)
```bash
azd up
# 배포 중 bastion VM 패스워드를 프롬프트로 입력받습니다
```

### 2. SSH 키 인증으로 배포
```bash
./setup-ssh.sh  # SSH 키 생성 및 .env 파일 자동 설정
azd up          # 패스워드 프롬프트 없이 배포
```

> **패스워드 복잡도 요구사항**
> - 6-72자 길이
> - 대문자, 소문자, 숫자, 특수문자 중 최소 3가지 조합 필수

> 참고: 이 배포 템플릿은 Ubuntu 20.04 LTS(Gen2) 이미지를 사용합니다. VM 크기는 워커 D2s v3, Bastion B1s로 지정되어 있습니다.

</details>

<details>
<summary><strong>VSCode에서 Azure Developer CLI Extension 설치</strong></summary>

1. VSCode 좌측 Extensions(확장) 메뉴 클릭
2. 'Azure Developer CLI' 검색 후 설치
3. 명령 팔레트(Ctrl+Shift+P)에서 `azd` 관련 명령 실행 가능

</details>

<details>
<summary><strong>예상 결과 리소스 구조</strong></summary>

- **Virtual Network**: vnet-{VMNAME}-krc-01
- **Subnets**: 
  - default (10.0.0.0/24) - Worker VMs용
  - bastion-subnet (10.0.1.0/24) - Bastion VM용
- **Network Security Groups**: 
  - nsg-{VMNAME}-krc-01 (VNet 내부 SSH만 허용)
  - nsg-bastion-{VMNAME}-krc-01 (외부 SSH 허용)
- **VMs**: 
  - {VMNAME}1 ~ {VMNAME}6 (Ubuntu 20.04 LTS, Private IP)
  - {VMNAME}-bastion (Ubuntu 20.04 LTS, Public IP)
- **NICs**: {VMNAME}1-nic ~ {VMNAME}6-nic, {VMNAME}-bastion-nic
- **Public IP**: {VMNAME}-bastion-pip (Bastion VM용)

</details>
