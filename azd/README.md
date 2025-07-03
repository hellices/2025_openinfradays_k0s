# Azure VM 배포 예제 (azd + Bicep)

<details>
<summary><strong>Azure Developer CLI(azd)로 Ubuntu VM 7대 배포하기</strong></summary>

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
3. 환경 변수(.env) 설정 예시
   ```env
   ADMIN_PASSWORD=패스워드
   VMNAME=openinfradays
   AZURE_RESOURCE_GROUP=rg-openinfradays-krc-01
   ```
4. azd 프로젝트 초기화 (최초 1회)
   ```bash
   azd init
   ```
5. 배포
   ```bash
   azd up
   ```

## 옵션/파라미터
- VMNAME: VM 이름 패턴 접두어 (예: openinfradays)
- ADMIN_PASSWORD: Ubuntu VM의 관리자 비밀번호
- vmCount: VM 개수 (기본 7, 필요시 main.bicep에서 수정)

## 주요 azd 명령어
- 배포: `azd up`
- 삭제: `azd down`
- 상태 확인: `azd show`

</details>

<details>
<summary><strong>VSCode에서 Azure Developer CLI Extension 설치</strong></summary>

1. VSCode 좌측 Extensions(확장) 메뉴 클릭
2. 'Azure Developer CLI' 검색 후 설치
3. 명령 팔레트(Ctrl+Shift+P)에서 `azd` 관련 명령 실행 가능

</details>

<details>
<summary><strong>예상 결과 리소스 구조</strong></summary>

- Virtual Network: vnet-{VMNAME}-krc-01
- Subnet: default
- Network Security Group: nsg-{VMNAME}-krc-01 (SSH 22번만 허용)
- VM: {VMNAME}1 ~ {VMNAME}7 (Ubuntu 20.04 LTS)
- NIC: {VMNAME}1-nic ~ {VMNAME}7-nic

</details>
