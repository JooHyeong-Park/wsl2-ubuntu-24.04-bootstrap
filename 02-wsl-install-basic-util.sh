#!/bin/bash

# strict 모드 활성화 (오류 발생 시 즉시 중단)
# -E : ERR 트랩을 함수 / 서브셸에서도 상속
# -e : 명령 실행 중 오류(exit code ≠ 0) 발생 시 즉시 종료
# -u : 선언되지 않은 변수를 사용하면 오류로 처리
# -o pipefail : 파이프라인(|) 중간 명령이 실패해도 실패로 인식
set -Eeuo pipefail

# WSL OpenSSH Server 에 설정할 SSH Port 번호
# - 기본값 10022 : Windows 호스트 또는 다른 SSH 서비스와의 충돌 방지 위해 기본 22 가 아닌 별도 Port 지정
SSH_PORT_NUMBER="10022"

if ! [[ "${SSH_PORT_NUMBER}" =~ ^[1-9][0-9]{0,4}$ ]] || (( 10#${SSH_PORT_NUMBER} > 65535 )); then
  echo "[ERROR] SSH_PORT_NUMBER must be between 1 and 65535: ${SSH_PORT_NUMBER}" >&2
  exit 1
fi

echo -e "########## WSL2 Ubuntu 24.04 Basic Util 설치 :: START ##########"
echo ""

########## Update Ubuntu 24.04 Sources and APT ##########

# APT Repository URL 기본값 : http://archive.ubuntu.com/ubuntu/, http://security.ubuntu.com/ubuntu/ (security)
# -> http 아닌 https 통신 위해 별도 지정, 필요시 'https://mirror.kakao.com/ubuntu' 등 지정 가능
APT_REPOSITORY_URL='https://archive.ubuntu.com/ubuntu/'
APT_SECURITY_REPOSITORY_URL='https://security.ubuntu.com/ubuntu/'

echo -e "[INFO] /etc/apt/sources.list.d/ubuntu.sources 수정"
sudo tee /etc/apt/sources.list.d/ubuntu.sources > /dev/null << EOF
### 수정된 ubuntu.sources

# See http://help.ubuntu.com/community/UpgradeNotes for how to upgrade to
# newer versions of the distribution.

## Ubuntu distribution repository
##
## The following settings can be adjusted to configure which packages to use from Ubuntu.
## Mirror your choices (except for URIs and Suites) in the security section below to
## ensure timely security updates.
##
## Types: Append deb-src to enable the fetching of source package.
## URIs: A URL to the repository (you may add multiple URLs)
## Suites: The following additional suites can be configured
##   <name>-updates   - Major bug fix updates produced after the final release of the
##                      distribution.
##   <name>-backports - software from this repository may not have been tested as
##                      extensively as that contained in the main release, although it includes
##                      newer versions of some applications which may provide useful features.
##                      Also, please note that software in backports WILL NOT receive any review
##                      or updates from the Ubuntu security team.
## Components: Aside from main, the following components can be added to the list
##   restricted  - Software that may not be under a free license, or protected by patents.
##   universe    - Community maintained packages. Software in this repository receives maintenance
##                 from volunteers in the Ubuntu community, or a 10 year security maintenance
##                 commitment from Canonical when an Ubuntu Pro subscription is attached.
##   multiverse  - Community maintained of restricted. Software from this repository is
##                 ENTIRELY UNSUPPORTED by the Ubuntu team, and may not be under a free
##                 licence. Please satisfy yourself as to your rights to use the software.
##                 Also, please note that software in multiverse WILL NOT receive any
##                 review or updates from the Ubuntu security team.
##
## See the sources.list(5) manual page for further settings.
Types: deb
URIs: ${APT_REPOSITORY_URL}
Suites: noble noble-updates noble-backports
Components: main universe restricted multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

## Ubuntu security updates. Aside from URIs and Suites,
## this should mirror your choices in the previous section.
Types: deb
URIs: ${APT_SECURITY_REPOSITORY_URL}
Suites: noble-security
Components: main universe restricted multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

EOF

echo -e "[INFO] 'apt-get update' 로 APT Mirror Repo 반영 확인"
sudo apt-get update
echo ""


########## Install Basic APT Utilities ##########

echo -e "[INFO] WSL 환경에서 사용할 APT 기본 Util 설치 :: START"

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  curl wget make locales tzdata \
  openssh-server openssh-client \
  lsof psmisc gnupg ca-certificates \
  zip unzip xz-utils iproute2 bind9-dnsutils binutils procps \
  jq yq tree ripgrep fd-find bat \
  dbus-user-session iptables

# - fdfind -> fd 링크 생성 :: 'fd <파일명> [경로]' , 파일명/디렉터리 검색
# - batcat -> bat 링크 생성 :: 'bat <파일>' , 줄 번호와 구문 강조를 적용해 파일 내용 출력
sudo ln -sfn "$(command -v fdfind)" /usr/local/bin/fd
sudo ln -sfn "$(command -v batcat)" /usr/local/bin/bat

echo -e "[INFO] WSL 환경에서 사용할 APT 기본 Util 설치 :: END"
echo ""


########## Configure OpenSSH Server ##########

sudo install -d -m 0755 /etc/ssh/sshd_config.d
sudo tee /etc/ssh/sshd_config.d/99-wsl-custom.conf > /dev/null << EOF
# WSL2 remote SSH configuration
Port ${SSH_PORT_NUMBER}
PubkeyAuthentication yes
PasswordAuthentication yes
PermitRootLogin no
EOF

sudo install -d -m 0755 /run/sshd
sudo sshd -t
sudo systemctl daemon-reload
sudo systemctl enable --now ssh.socket
sudo systemctl restart ssh.socket

echo -e "[INFO] WSL OpenSSH Server 설정 (SSH Port '${SSH_PORT_NUMBER}')"
echo ""


########## Install Python Tools and Podman Compose Dependencies ##########

echo -e "[INFO] 기본 Python 설치 버전 확인"
python3 --version
# Console Output :: "Python 3.12.3"

# python3-pip  : 시스템 pip
# python3-venv : 가상환경 (venv) 생성
# python3-dotenv, python3-yaml : podman-compose.py 실행시 필요
echo -e "[INFO] 시스템 Python 관련 패키지 및 podman-compose 의존성 설치 ::: START"
sudo apt-get install -y --no-install-recommends \
  python3-pip \
  python3-venv \
  python3-dotenv \
  python3-yaml
echo -e "[INFO] 시스템 Python 관련 패키지 및 podman-compose 의존성 설치 ::: END"

echo -e "[INFO] podman-compose Python 의존성 PyYAML, python-dotenv 모듈 및 버전 확인"
python3 - <<'PYTHON'
import dotenv, yaml
from importlib.metadata import version

print(f"PyYAML :: {version('PyYAML')}")
print(f"python-dotenv :: {version('python-dotenv')}")
PYTHON
echo ""


########## Install Rootless Podman ##########

# Rootless Podman => netavark, aardvark-dns, pasta, slirp4netns, uidmap 필수
# - podman/README.md :: OCI Projects Plans
#   https://github.com/containers/podman/blob/main/README.md#oci-projects-plans
#
#   Networking: Networking support through use of `Netavark` and `Aardvark`. Rootless networking is handled via `pasta` or `slirp4netns`.
#
# - Podman :: Rootless Containers
#   https://docs.podman.io/en/stable/markdown/podman-run.1.html#rootless-containers
#
#   Podman runs as a non-root user on most systems. This feature requires that a new enough version of `shadow-utils` be installed.
#   The `shadow-utils` package must include the newuidmap(1) and newgidmap(1) executables.
#   In order for users to run rootless, there must be an entry for their username in /etc/subuid and /etc/subgid which lists the UIDs for their user namespace.
#   => [Note] uidmap 설치로 대체
#
#   To enable VPN on the container, `slirp4netns` or `pasta` needs to be specified; without either, containers need to be run with the --network=host flag.
#
# - /etc/subuid and /etc/subgid
#   https://rootlesscontaine.rs/getting-started/common/subuid
#
#   newuidmap and newgidmap needs to be installed on the host. These binaries are typically installed by default.
#   `sudo apt-get install -y uidmap`
#
# - Shortcomings of Rootless Podman
#   https://github.com/containers/podman/blob/main/rootless.md
#
#   Support for using native overlayfs as an unprivileged user is only available for Podman version >= 3.1 on a Linux kernel version >= 5.12, otherwise the slower fuse-overlayfs will be used.
#   => [Note] Podman version >= 3.1, Linux kernel version >= 5.12 이상이면 native overlayfs 사용 가능하므로 fuse-overlayfs 설치하지 않음
#
# - How to Use Podman for Socket Activation
#   https://oneuptime.com/blog/post/2026-03-18-use-podman-socket-activation/view

echo -e "[INFO] Rootless Podman 설치 :: START"

sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  podman \
  netavark \
  aardvark-dns \
  passt \
  slirp4netns \
  uidmap

echo -e "[INFO] Rootless Podman 설치 :: END"
echo ""

echo -e "[INFO] Rootless Podman 을 위한 subuid / subgid 설정 확인"
# Rootless Podman 은 user namespace 를 사용하므로 /etc/subuid, /etc/subgid 에 사용자별 UID/GID 매핑 범위가 필요함
grep "^$USER:" /etc/subuid || echo "[WARNING] /etc/subuid 에 '${USER}' 항목이 없습니다."
grep "^$USER:" /etc/subgid || echo "[WARNING] /etc/subgid 에 '${USER}' 항목이 없습니다."
echo ""

echo -e "[INFO] Rootless Podman 을 위한 linger 활성화"
# [loginctl enable-linger 설정]
# - Rootless Podman 은 user-level systemd (systemd --user) 를 기반으로 동작함
#   사용자가 로그인하지 않은 상태에서도 해당 사용자의 systemd --user 인스턴스를 계속 유지하도록 설정하며,
#   터미널 종료 / SSH 세션 종료 이후에도 rootless Podman 관련 user 서비스, 소켓, 컨테이너가 정상 동작하도록 보장함
# - 본 설정은 systemd 가 활성화된 환경에서만 동작함
#   WSL 의 경우 /etc/wsl.conf 에서 systemd=true 설정 후 WSL 재시작(wsl --shutdown)이 선행되어야 함
sudo loginctl enable-linger "$USER"
echo ""

echo -e "[INFO] Podman 버전 확인"
podman --version
# Console Output :: "podman version 4.9.3"

echo ""


########## Configure Podman ##########
# [Reference]
# - Podman - storage.conf
#   https://github.com/containers/storage/blob/main/docs/containers-storage.conf.5.md
#
# - Podman - registries.conf
#   https://github.com/containers/image/blob/main/docs/containers-registries.conf.5.md
#
# - Podman - containers.conf
#   https://github.com/containers/common/blob/main/docs/containers.conf.5.md

# Rootless Podman 전용 data directory (기본값: '~/.local/share/containers/storage')
PODMAN_DATA_ROOT='/data01/podman-data'

# Rootless Podman 전용 설정 파일 경로
PODMAN_CONFIG_DIR="${HOME}/.config/containers"

echo -e "[INFO] Rootless Podman 전용 데이터 경로 '${PODMAN_DATA_ROOT}' 별도 생성, permission 수정"
sudo mkdir -p "${PODMAN_DATA_ROOT}"
sudo chown -R "${USER}:${USER}" "${PODMAN_DATA_ROOT}"

echo -e "[INFO] Rootless Podman 전용 storage.conf 설정"
mkdir -p "${PODMAN_CONFIG_DIR}"
cat <<EOF > "${PODMAN_CONFIG_DIR}/storage.conf"
[storage]
driver = "overlay"
graphroot = "${PODMAN_DATA_ROOT}"
EOF

# 'insecure-registry' 로 샘플 도메인 "registry.example.com:5000" 등록
echo -e "[INFO] Rootless Podman 전용 registries.conf 생성, insecure-registry 등록"
cat <<EOF > "${PODMAN_CONFIG_DIR}/registries.conf"
[[registry]]
location = "registry.example.com:5000"
insecure = true
EOF

echo -e "[INFO] Rootless Podman 전용 containers.conf 생성, 로그 로테이션 설정"
cat <<EOF > "${PODMAN_CONFIG_DIR}/containers.conf"
[containers]
# Docker의 log-driver=json-file 및 max-size=10m 에 대응
log_driver = "k8s-file"
log_size_max = 10485760  # 10MB

[engine]
# Build cache management is recommended to use 'podman system prune' or periodic timers
EOF

echo ""


########## Install Podman Compose ##########

# @Reference
# - containers/podman-compose
#   https://github.com/containers/podman-compose
# @Version     v1.6.0 / Release Date 2026-06-04
#              -> sudo apt-get install 로 podman-compose 설치시 상대적으로 구버전 (1.0.6 (Release Date 2023-04-09) 설치됨

PODMAN_COMPOSE_VERSION=v1.6.0
PODMAN_COMPOSE_DOWNLOAD_URL=https://raw.githubusercontent.com/containers/podman-compose/${PODMAN_COMPOSE_VERSION}/podman_compose.py

curl -G --silent -f \
  -o "${HOME}"/podman-compose \
  -L "${PODMAN_COMPOSE_DOWNLOAD_URL}"

chmod +x "${HOME}"/podman-compose
sudo mv "${HOME}"/podman-compose /usr/local/bin/podman-compose

echo -e "[INFO] Podman Compose 설치 확인"
podman-compose version
# Console Output :: "podman-compose version: 1.6.0"

echo ""


########## Clean Up ##########

# echo -e "[INFO] 마지막으로 APT update, upgrade"
# sudo apt-get update
# sudo apt-get upgrade -y

echo -e "[INFO] APT 정리"
sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/*

echo ""
echo -e "########## WSL2 Ubuntu 24.04 Basic Util 설치 :: END --> WSL 재부팅 필요 ##########"
