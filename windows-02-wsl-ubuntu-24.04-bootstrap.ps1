# windows-02-wsl-ubuntu-24.04-bootstrap.ps1
#
# WSL2 Ubuntu 24.04 환경 전용 bootstrap 스크립트들을 순차 실행합니다.

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

# Linux 스크립트 파일을 WSL2 Ubuntu 24.04 내 복사 후 실행
function Invoke-WslScript {
  param (
    [string]$wslDistroName = $distroName,
    [string]$linuxScriptRelativePath,
    [string]$wslScriptPath,
    [bool]$executeWslScript = $true,
    [bool]$deleteWslScript = $true,
    [bool]$terminateWSL = $false,
    [string[]]$linuxScriptArgs = @()
  )

  $linuxScriptAbsolutePath = Join-Path -Path $PSScriptRoot -ChildPath $linuxScriptRelativePath

  if (-not (Test-Path -Path $linuxScriptAbsolutePath -PathType Leaf)) {
      throw "[ERROR] Script file not found: $linuxScriptAbsolutePath"
  }

  Write-Output "`n[INFO] Linux script path in Windows Host :: $linuxScriptAbsolutePath"

  if($deleteWslScript) {
    $wslScriptPath = '/tmp'
  }

  $wslScriptFileName = [System.IO.Path]::GetFileName($linuxScriptAbsolutePath)
  $wslScriptAbsolutePath = "$wslScriptPath/$wslScriptFileName"

  Write-Output "[INFO] Linux script path in WSL ::: $wslScriptAbsolutePath`n"

  # Linux 스크립트를 UTF-8 로 읽기
  $linuxScriptContent = Get-Content -Path $linuxScriptAbsolutePath -Raw -Encoding UTF8

  # 인코딩 문제 방지를 위해 스크립트를 Bytes -> Base64 로 변환
  # $encodedContent = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($linuxScriptContent))
  $encoding = [System.Text.Encoding]::UTF8
  $scriptBytes = $encoding.GetBytes($linuxScriptContent)
  $encodedContent = "$([System.Convert]::ToBase64String($scriptBytes, 0, $scriptBytes.Length))"

  # WSL 내부에서 Base64 디코딩 -> 실행 스크립트 생성
  $prepCommand = "echo $encodedContent | base64 -d > $wslScriptAbsolutePath && chmod +x $wslScriptAbsolutePath"
  Invoke-WslChecked -Arguments @('-d', $wslDistroName, 'bash', '-c', $prepCommand)

  # WSL 내부에서 스크립트 실행
  if ($executeWslScript) {
    $argsString = [string]::Join(" ", $linuxScriptArgs)
    Write-Output "`n########## EXECUTE '$wslScriptAbsolutePath $argsString' IN WSL :: START ##########`n"
    Invoke-WslChecked -Arguments @('-d', $wslDistroName, 'bash', '-c', "$wslScriptAbsolutePath $argsString")
    Write-Output "`n########## EXECUTE '$wslScriptAbsolutePath $argsString' IN WSL :: END ##########`n"
  }

  if($deleteWslScript) {
    Write-Output "[INFO] delete temp script in WSL`n"
    Invoke-WslChecked -Arguments @('-d', $wslDistroName, 'bash', '-c', "rm -f $wslScriptAbsolutePath")
  }

  # Ubuntu-24.04 WSL 환경 종료
  if ($terminateWSL) {
      Write-Output "[INFO] terminate WSL`n"
      Invoke-WslChecked -Arguments @('-t', $wslDistroName)
  }
}

##################################################
### Function Definition :: END
##################################################

# WSL2 Ubuntu 24.04 최초 설정
Invoke-WslScript -linuxScriptRelativePath "./01-wsl-initial-setup.sh" -terminateWSL $true

# WSL2 Ubuntu 24.04 Basic Util 설치
Invoke-WslScript -linuxScriptRelativePath "./02-wsl-install-basic-util.sh" -terminateWSL $true

# WSL2 Ubuntu 24.04 Extra Util 설치
Invoke-WslScript -linuxScriptRelativePath "./03-wsl-install-extra-util.sh"
