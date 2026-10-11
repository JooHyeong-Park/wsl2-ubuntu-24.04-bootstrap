# WSL2 Ubuntu 24.04 환경 구성 자동화

개인 Windows PC에서 Linux 기반 개발환경을 쉽고 빠르게 구축하기 위한 자동화 프로젝트입니다.<br>
PowerShell 스크립트 기반으로 WSL2 Ubuntu 24.04 설치부터 시스템 초기 설정, 개발 도구 구성까지 자동화합니다.<br>
<br>
스트립트 실행시 다음 기능들을 포함한 통합 개발 환경이 구성됩니다.

| Category | Features |
| --- | --- |
| **Container** | Rootless Podman, podman-compose, KinD, kubectl, helm 3 |
| **Programming** | Python 3.13, OpenJDK 21, Node.js 22 LTS |
| **Azure** | Azure CLI, Bicep |
| **AI Coding Agent** | Codex, OpenCode |
| **GPU** | NVIDIA Container Toolkit, HuggingFace CLI |

사용자의 목적에 따라 필요한 도구와 설정들을 쉽게 추가/확장할 수 있도록 개발하였습니다.<br>
다만 직접 스크립트를 수정하기보단, AI Agent 에 맞기는 것을 권장합니다.

## 사전 요구사항

- WSL2 및 개발 도구 설치를 위한 인터넷 연결
- Windows 11 22H2 이상 권장 : WSL `Mirrored mode networking` 기능 사용시 필수
  - [WSL을 사용하여 네트워크 애플리케이션 액세스](https://learn.microsoft.com/ko-kr/windows/wsl/networking)
- CPU/윈도우 가상화 관련 기능 활성화
  - [Microsoft - Windows에서 가상화 활성화](https://support.microsoft.com/ko-kr/windows/experience/enable-virtualization-on-windows)
  - [Microsoft - WSL 문제 해결](https://learn.microsoft.com/ko-kr/windows/wsl/troubleshooting)
- NVIDIA GPU 관련 기능 사용시 : CUDA 지원 GPU 와 호환되는 Windows 전용 NVIDIA 그래픽 드라이버 설치
  - [NVIDIA - Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/)
  - [NVIDIA - CUDA on WSL User Guide](https://docs.nvidia.com/cuda/wsl-user-guide/index.html)

## 설치 및 구성

### 1. PowerShell 실행 환경 설정

PowerShell `*.ps1` 스크립트 실행 허용을 위해 PowerShell 실행정책을 변경해야 합니다<br>
PowerShell 에서 아래 스크립트를 실행하세요.

```powershell
# PowerShell 실행 정책 확인
Get-ExecutionPolicy -List

# 현재 Windows 사용자의 PowerShell 스크립트 실행 허용
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### 2. Windows PC 에 WSL2 최초 설치

> [!NOTE]
> WSL2 가 설치되지 않은 Windows PC 에서 최초 1회만 수행합니다.<br>
> 여기서는 WSL2 자체만 설치하며, Ubuntu 24.04 환경 구성은 자동화 스크립트 기반으로 이후 단계에서 실행합니다.

PowerShell 을 `관리자 권한` 으로 실행한 후 WSL2 를 설치합니다.<br>
설치 후 Windows 를 재부팅하는 것을 권장합니다.

```powershell
# WSL2 최초 설치
wsl --install --no-distribution

# 기본 WSL 버전을 '2' 로 명시적 설정
wsl --set-default-version 2
```

PowerShell 실행 후 WSL2 설치 상태를 확인합니다.

```powershell
# WSL2 버전 확인
wsl --version

# WSL2 에 배포된 Linux distro 상태 확인
wsl --status
wsl -l -v
```

### 3. WSL2 전역 설정 `.wslconfig` 생성

> [!NOTE]
> WSL2 가 설치된 Windows PC 에서 최초 1회만 수행합니다.<br>
> 하단 .wslconfig 내 `memory`, `processors`, `swap` 값을 사용자 PC 의 하드웨어 사양에 맞게 조정 후 실행하세요.

다음 스크립트는 WSL2 전역 설정인 `.wslconfig` 를 자동으로 생성합니다.<br>
`memory`, `processors`, `swap` 값 수정 후 PowerShell 에서 아래 스크립트를 실행하세요.

```powershell
$wslConfigContent = @"
# [ Reference ]
# - Advanced settings configuration in WSL
#   https://learn.microsoft.com/en-us/windows/wsl/wsl-config

# Settings apply across all Linux distros running on WSL2
[wsl2]

# How much memory to assign to the WSL2 VM.
# Default: 50% of total memory on Windows
memory=30GB

# Default: The same number of logical processors on Windows
processors=14

# How much swap space to add to the WSL2 VM, 0 for no swap file.
# Swap storage is disk-based RAM used when memory demand exceeds limit on hardware device.
# Default: 25% of memory size on Windows rounded up to the nearest GB
swap=8GB

# Additional kernel command line arguments.
#
# [Reference]
# - Using the Docker images in production
#   https://www.elastic.co/docs/deploy-manage/deploy/self-managed/install-elasticsearch-docker-prod
# - Installing OpenSearch
#   https://opensearch.org/docs/latest/install-and-configure/install-opensearch/index/#important-settings
kernelCommandLine="sysctl.vm.max_map_count=262144"

# Boolean to turn on or off support for GUI applications (WSLg) in WSL.
# Default: true
guiApplications=false

# Enable mirrored networking so WSL services can be reached through the Windows host network, including Tailscale.
networkingMode=mirrored

# Apply Windows Firewall and Hyper-V firewall rules to WSL traffic.
firewall=true

# Route WSL DNS queries through Windows for VPN and Tailscale DNS compatibility.
dnsTunneling=true

[experimental]
# Reclaim unused WSL memory by dropping the Linux page cache.
autoMemoryReclaim=dropcache

# Allow WSL to connect to IPv4 addresses assigned to the Windows host.
hostAddressLoopback=true
"@

# 현재 사용자의 Windows USERPROFILE 경로 확인
Write-Host $env:USERPROFILE

$wslConfigPath = Join-Path $env:USERPROFILE ".wslconfig"

# .wslconfig 파일이 이미 있는지 확인
if (-not (Test-Path -LiteralPath $wslConfigPath)) {
  Write-Host "`n[INFO] Creating $wslConfigPath`n"

  # .wslconfig 생성
  $encoding = New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText(
    $wslConfigPath,
    $wslConfigContent + [Environment]::NewLine,
    $encoding
  )

  Write-Host "[INFO] .wslconfig created successfully.`n"

} else {
  Write-Host "`n[WARN] $env:USERPROFILE 경로에 .wslconfig 파일이 이미 존재합니다! 기존 내용을 확인하세요.`n"
}

```

### 4. 사용자 개인 환경에 맞춘 설정 변경

> [!NOTE]
> 개인 설정 값들을 직접 수정하기보단, AI Agent 의 분석 후 수정하는 것을 추천합니다.

각 스크립트에서 사용자 개인 환경에 맞춰 변경이 필요한 부분들을 확인 후 수정합니다.

- **01-wsl-initial-setup.sh**

  해당 스크립트에서 WSL2 접속시 기본 계정을 생성합니다. 기본 계정명은 `wsladmin` 입니다.<br>
  필요시 사용자 개인 설정에 맞게 값을 변경합니다.

  ```bash
  ########## 신규 User 등록 ##########

  # User : 'admin' 과 같이 Ubuntu 내 기본 계정으로 이미 존재하는 이름은 안됨
  # UID  : 1000 이상으로 설정
  NEW_USER=wsladmin
  NEW_USER_UID=2000
  NEW_USER_HOME_PATH="/home/${NEW_USER}"

  NEW_GROUP=wsladmin
  NEW_USER_GID=2000
  ```

  또한 WSL2 접속 계정 생성시 `DEFAULT_USER_PASSWORD` 에 지정된 임시 값으로 비밀번호를 지정합니다.<br>
  이는 초기 비밀번호이며 사용자가 실제 사용할 비밀번호로 변경해야 합니다.

- **02-wsl-install-basic-util.sh**

  해당 스크립트에서 WSL2 환경을 SSH 접속시 사용할 Port 번호를 지정합니다.<br>
  기본값은 `10022` 이며 필요시 변경합니다.

  ```bash
  # WSL OpenSSH Server 에 설정할 SSH Port 번호
  # - 기본값 10022 : Windows 호스트 또는 다른 SSH 서비스와의 충돌 방지 위해 기본 22 가 아닌 별도 Port 지정
  SSH_PORT_NUMBER="10022"
  ```

- **03-wsl-install-extra-util.sh**

  해당 스크립트에서 WSL2 개발 환경에 필요한 각종 Extra Util 들을 설치합니다.<br>
  만약 다른 필요한 Util 들이 있다면 해당 스크립트 내 각종 Sample 들을 참조하여 추가/수정할 수 있습니다.

> [!WARNING]
> NVIDIA Container Toolkit 관련 기능은 **NVIDIA GPU + NVIDIA 그래픽 드라이버 설치** 가 필수입니다.<br>
> GPU 가 없거나 관련 기능이 필요하지 않은 경우, `03-wsl-install-extra-util.sh` 내 아래 Code Block 에 해당하는<br>
> 부분들을 주석처리, 또는 삭제 후 스크립트를 실행하세요.

  ```bash
  ########## Install NVIDIA Container Toolkit ##########
  ...
  ########## Generate NVIDIA Container Device Interface (CDI) Specification ##########
  ...
  ########## Install HuggingFace CLI ##########
  ...
  ```

- **windows-03-wsl-ubuntu-24.04-post-setup.ps1**

  해당 스크립트에서 WSL2 개발 환경 내 .gitconfig 에 설정할 Username/Email, bash shell 접속시 aliases 등을 설정합니다.<br>
  아레 예시에서 **dev-01** 과 같이 임시로 지정된 값들을 사용자 개인 설정에 맞게 변경합니다.

  ```powershell
  # [Note] GIT_USER_NAME, GIT_USER_EMAIL , Aliases 등을 사용자 개인 설정에 맞게 설정하세요

  $wslEnvironment = @{
    # Git User name
    GIT_USER_NAME = 'dev-01'

    # Git User email
    GIT_USER_EMAIL = 'dev-01@example.com'

    # ~/.bash_aliases 에 작성할 aliases 목록
    BASH_ALIASES = @'
  ### Add Custom Aliases

  alias k='kubectl'
  alias watch='watch '

  # 기본 Python 명령어로 Python 3.13 지정 (단, 시스템 python3 는 3.12 유지)
  alias python='python3.13'
  alias python3='python3.13'
  alias pip='python3.13 -m pip'
  alias pip3='python3.13 -m pip'
  '@
  }
  ```

### 5. WSL2 Ubuntu 24.04 환경 구성 자동화 스크립트 실행

PowerShell 에서 스크립트 디렉터리 경로로 이동 후 `windows-01-wsl-ubuntu-24.04-provision.ps1` 을 실행합니다.

> [!WARNING]
> `windows-01-wsl-ubuntu-24.04-provision.ps1` 은 기존 WSL2 Ubuntu-24.04 환경을 삭제하고 새로 설치합니다.<br>
> 기존 환경의 모든 데이터가 영구 삭제되므로 최초 구성시, 또는 재설치가 필요한 경우에만 실행하세요.<br>
> 또한 재설치시 기존 WSL2 Ubuntu-24.04 환경의 Data 들을 미리 백업해야 합니다.

```powershell
# 스크립트 디렉터리 경로로 이동
Set-Location "<스크립트 디렉터리 경로>"

# WSL2 Ubuntu-24.04 환경 신규 구성
.\windows-01-wsl-ubuntu-24.04-provision.ps1
```

이후 `windows-02-wsl-ubuntu-24.04-bootstrap.ps1` 을 실행합니다.

> [!NOTE]
> `windows-02-wsl-ubuntu-24.04-bootstrap.ps1` 은 `01-wsl-initial-setup.sh` ~ `03-wsl-install-extra-util.sh`<br>
> 순서로 Ubuntu 24.04 전용 bootstrap 스크립트들을 순차 실행합니다.

```powershell
# WSL2 Ubuntu-24.04 환경 전용 bootstrap 스크립트들을 순차 실행
.\windows-02-wsl-ubuntu-24.04-bootstrap.ps1
```

마지막으로 `windows-03-wsl-ubuntu-24.04-post-setup.ps1` 을 실행합니다.

```powershell
# WSL2 Ubuntu-24.04 환경 구성 이후 추가 작업을 실행합니다.
.\windows-03-wsl-ubuntu-24.04-post-setup.ps1
```

## WSL2 Ubuntu 24.04 접속

Visual Studio Code 의 `Remote Development` extension 을 사용하여 접속하는 것을 권장합니다.<br>
다음 레퍼런스들을 참조하세요

- [Developing in WSL](https://code.visualstudio.com/docs/remote/wsl)
- [Remote Development Extension Pack](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.vscode-remote-extensionpack)

## 참고 문서

- [Microsoft - Install WSL](https://learn.microsoft.com/en-us/windows/wsl/install)
- [Microsoft - Basic commands for WSL](https://learn.microsoft.com/en-us/windows/wsl/basic-commands)
- [Microsoft - Advanced settings configuration in WSL](https://learn.microsoft.com/en-us/windows/wsl/wsl-config)
