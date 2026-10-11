# windows-03-wsl-ubuntu-24.04-post-setup.ps1
#
# WSL2 Ubuntu-24.04 환경 구성 이후 추가 작업을 실행합니다.

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

# 여러 줄의 Bash 명령을 Base64 로 인코딩해 WSL 에서 실행
function Invoke-WslCommand {
  param (
    [string]$wslDistroName = $distroName,
    [string]$wslCommand,
    [bool]$useSudo = $false,
    [hashtable]$environmentVariables = @{}
  )

  if ([string]::IsNullOrEmpty($wslCommand)) { return }

  $encoding = [System.Text.Encoding]::UTF8

  # PowerShell 변수를 Base64 환경 변수 설정으로 변환해 Bash 명령 앞에 추가
  $environmentSetup = foreach ($name in $environmentVariables.Keys) {
    if ($name -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
      throw "[ERROR] Invalid environment variable name '$name'"
    }

    $environmentValueBytes = $encoding.GetBytes([string]$environmentVariables[$name])
    $encodedValue = [System.Convert]::ToBase64String($environmentValueBytes)
    "export ${name}=`$(printf '%s' '${encodedValue}' | base64 -d)"
  }

  if ($environmentSetup) {
    $environmentSetupText = $environmentSetup -join "`n"
    $wslCommand = "set -Eeuo pipefail`n${environmentSetupText}`n${wslCommand}"
  }

  # 명령 문자열을 Base64 로 인코딩해 안전하게 전달
  $commandTail = $wslCommand.TrimEnd()
  if ([int][char]$commandTail[$commandTail.Length - 1] -ne 34) {
    $wslCommand = $commandTail + '"'
  }
  $commandBytes = $encoding.GetBytes($wslCommand)
  $encodedContent = [System.Convert]::ToBase64String($commandBytes)

  $sudoPrefix = if ($useSudo) { "sudo " } else { "" }

  # Ubuntu-24.04 WSL 환경에서 명령 디코딩 후 실행
  Invoke-WslChecked -Arguments @('-d', $wslDistroName, 'bash', '-c', "echo $encodedContent | base64 -d | ${sudoPrefix}bash")
}

##################################################
### Function Definition :: END
##################################################


# [Note]
# 하단 GIT_USER_NAME, GIT_USER_EMAIL, Aliases 등을 사용자 개인 설정에 맞게 설정하세요

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

$wslCommand = @'
# strict 모드 활성화 (오류 발생 시 즉시 중단)
# -E : ERR 트랩을 함수 / 서브셸에서도 상속
# -e : 명령 실행 중 오류(exit code ≠ 0) 발생 시 즉시 종료
# -u : 선언되지 않은 변수를 사용하면 오류로 처리
# -o pipefail : 파이프라인(|) 중간 명령이 실패해도 실패로 인식
set -Eeuo pipefail

########## ~/.local/bin PATH 설정 ##########

USER_LOCAL_BIN_PATH="${HOME}/.local/bin"

if ! grep -Fq "${USER_LOCAL_BIN_PATH}" "${HOME}/.bashrc"; then
  printf "\nexport PATH=\"%s:\$PATH\"\n" "${USER_LOCAL_BIN_PATH}" >> "${HOME}/.bashrc"
  echo "[INFO] ~/.bashrc PATH 에 '${HOME}/.local/bin' 추가 :: 새로운 Bash 세션 로그인부터 적용됨"
else
  echo "- ~/.bashrc PATH 에 '${HOME}/.local/bin' 이 이미 등록되어 있습니다."
fi

########## .bash_aliases 기반 Alias 설정 ##########

# ~/.bash_aliases 를 아래 내용으로 덮어씁니다.
echo -e "\n[INFO] ~/.bash_aliases 설정"
printf '%s\n' "${BASH_ALIASES}" > "${HOME}/.bash_aliases"

########## ~/.gitconfig 생성 ##########

# ~/.gitconfig 전체를 아래 내용으로 덮어씁니다.
echo -e "\n[INFO] ~/.gitconfig 설정\n"

tee "${HOME}/.gitconfig" <<EOF
[core]
  autocrlf = input
  eol = lf
[http]
  sslVerify = true
[credential]
  helper = store
[safe]
  directory = *
[user]
  name = ${GIT_USER_NAME}
  email = ${GIT_USER_EMAIL}

EOF

########## ~/.git-credentials 생성 ##########

GIT_CREDENTIALS_PATH="${HOME}/.git-credentials"
touch "${GIT_CREDENTIALS_PATH}"
chmod 600 "${GIT_CREDENTIALS_PATH}"

echo "[INFO] Git credentials '${GIT_CREDENTIALS_PATH}' 파일 생성 :: 실제 Git 연동 정보는 수동으로 추가할 것"

'@

# WSL 기본 사용자 계정으로 해당 Command 실행
Invoke-WslCommand -wslCommand $wslCommand -environmentVariables $wslEnvironment
