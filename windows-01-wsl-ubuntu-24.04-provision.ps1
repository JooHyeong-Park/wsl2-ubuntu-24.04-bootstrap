# windows-01-wsl-ubuntu-24.04-provision.ps1
#
# WSL2 Ubuntu 24.04 환경을 신규 구성합니다.

# PowerShell 명령어 오류 처리를 위한 기본 설정:
# - 'Continue': 종료되지 않는 오류를 표시하고 계속 실행 (기본값)
# - 'Stop': 종료되지 않는 오류도 치명적인 오류로 처리하여 실행 중단
# - 'SilentlyContinue': 종료되지 않는 오류를 표시하지 않고 계속 실행
#
# wsl.exe 의 종료 코드는 Invoke-WslChecked 함수에서 별도로 확인
$ErrorActionPreference = 'Stop'

# 선언되지 않은 변수 사용 등 오류를 조기에 감지하도록 Strict 모드 적용
Set-StrictMode -Version 3.0

# WSL2 distro 'Ubuntu-24.04'
$distroName = 'Ubuntu-24.04'


##################################################
### Function Definition :: START
##################################################

# wsl.exe 의 실행 실패는 ErrorActionPreference 로 처리되지 않으므로,
# 종료 코드를 확인하여 오류 발생 시 스크립트 실행을 중단하도록 처리
function Invoke-WslChecked {
  param (
    [Parameter(Mandatory)]
    [string[]]$Arguments
  )

  & wsl @Arguments

  if ($LASTEXITCODE -ne 0) {
    throw "[ERROR] wsl command failed (exit code $LASTEXITCODE): wsl $($Arguments -join ' ')"
  }
}

##################################################
### Function Definition :: END
##################################################


# 현재 설치된 WSL 버전 확인
Invoke-WslChecked -Arguments @('--version')

# WSL 최신 커널로 update
Invoke-WslChecked -Arguments @('--update')

# 기존 모든 WSL 환경 종료
Invoke-WslChecked -Arguments @('--shutdown')

# 설치된 WSL 환경 목록 확인
$installedDistros = @(
  & wsl --list --quiet | ForEach-Object {
    ($_ -replace "`0", "").Trim()
  } | Where-Object { $_ }
)

# WSL 환경 목록 조회 실패시 스크립트 실행 중단
if ($LASTEXITCODE -ne 0) {
  throw "[ERROR] Failed to retrieve installed WSL distributions."
}

# 기존 Ubuntu-24.04 환경이 이미 있는 경우 unregister -> 즉, 삭제
if ($installedDistros -contains $distroName) {
  Write-Host ""
  $confirmation = Read-Host '[WARNING] 기존 WSL2 '$distroName' 내 모든 데이터를 삭제하고 새로 설치합니다. 계속 진행할까요? (y/n) '

  if ($confirmation -notmatch '^[yY]$') {
    Write-Host ""
    Write-Host "[INFO] WSL2 '$distroName' 삭제 및 재설치를 취소했습니다. 스크립트를 종료합니다."
    Write-Host ""
    exit 0
  }

  Write-Host ""
  Invoke-WslChecked -Arguments @('--unregister', $distroName)
}

# WSL2 Ubuntu-24.04 환경 설치
Invoke-WslChecked -Arguments @('--install', '-d', $distroName, '--no-launch')
