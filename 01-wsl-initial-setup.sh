#!/bin/bash

# strict 모드 활성화 (오류 발생 시 즉시 중단)
# -E : ERR 트랩을 함수 / 서브셸에서도 상속
# -e : 명령 실행 중 오류(exit code ≠ 0) 발생 시 즉시 종료
# -u : 선언되지 않은 변수를 사용하면 오류로 처리
# -o pipefail : 파이프라인(|) 중간 명령이 실패해도 실패로 인식
set -Eeuo pipefail

echo -e "########## WSL2 Ubuntu 24.04 최초 설정 :: START ##########"
echo ""

########## 신규 User 등록 ##########

# User : 'admin' 과 같이 Ubuntu 내 기본 계정으로 이미 존재하는 이름은 안됨
# UID  : 1000 이상으로 설정
NEW_USER=wsladmin
NEW_USER_UID=2000
NEW_USER_HOME_PATH="/home/${NEW_USER}"

NEW_GROUP=wsladmin
NEW_USER_GID=2000

DEFAULT_USER_PASSWORD=wsl1!

echo -e "[INFO] 신규 Group '${NEW_GROUP}' 추가 :: GID '${NEW_USER_GID}' 지정"
if getent group "${NEW_GROUP}" > /dev/null; then
  echo "- Group '${NEW_GROUP}' 이 이미 존재 :: groupadd 를 중단합니다."
else
  sudo groupadd --gid "${NEW_USER_GID}" "${NEW_GROUP}"
fi

echo -e "[INFO] 신규 User '${NEW_USER}' 추가 :: UID '${NEW_USER_UID}', Home 경로 '${NEW_USER_HOME_PATH}' 지정"
if id "${NEW_USER}" > /dev/null 2>&1; then
  echo "- User '${NEW_USER}' 이 이미 존재 :: useradd 를 중단합니다."
else
  sudo useradd \
    --uid "${NEW_USER_UID}" --gid "${NEW_USER_GID}" \
    --home-dir "${NEW_USER_HOME_PATH}" --create-home \
    --shell /bin/bash \
    "${NEW_USER}"
fi

echo -e "[INFO] 신규 User '${NEW_USER}' 를 sudo 그룹에 추가"
sudo usermod -a -G sudo "${NEW_USER}"

echo -e "[INFO] 신규 User '${NEW_USER}' 에 nopasswd 권한 부여"
SUDOERS_FILE="/etc/sudoers.d/${NEW_USER}-nopasswd"
echo "${NEW_USER} ALL=(ALL) NOPASSWD: ALL" | sudo tee "${SUDOERS_FILE}" > /dev/null
sudo chmod 440 "${SUDOERS_FILE}"
sudo visudo -cf "${SUDOERS_FILE}"

echo -e "[INFO] 신규 User '${NEW_USER}' 에 초기 password 설정"
echo "${NEW_USER}:${DEFAULT_USER_PASSWORD}" | sudo chpasswd
echo ""

########## /etc/wsl.conf 설정 ##########

# [Reference]
# - Advanced settings configuration in WSL :: Example wsl.conf file
#   https://learn.microsoft.com/ko-kr/windows/wsl/wsl-config#example-wslconf-file

echo -e "[INFO] WSL 관련 /etc/wsl.conf 설정"
sudo tee /etc/wsl.conf << EOF
# Set the user when launching a distribution with WSL.
[user]
default = ${NEW_USER}

[automount]
options = "metadata,uid=${NEW_USER_UID},gid=${NEW_USER_GID}"

[boot]
systemd=true

# 'mount --make-rshared /' :: Rootless Podman 기반 command 실행시 다음 WARN 방지
# -> "WARN[0000] "/" is not a shared mount, this could cause issues or missing mounts with rootless containers"
#
# [Reference]
# - Podman
#   https://wiki.alpinelinux.org/wiki/Podman
# - Install and Setup Podman in WSL2
#   https://aniketpathak028.medium.com/install-and-setup-podman-in-wsl2-4090304f8ce1
command="mount --make-rshared /"

EOF

echo ""

########## Timezone, Locale 설정 ##########

WSL_TIMEZONE="Asia/Seoul"
WSL_LOCALE="en_US.UTF-8"

echo -e "[INFO] '${WSL_TIMEZONE}' timezone 설정"
sudo ln -sfn "/usr/share/zoneinfo/${WSL_TIMEZONE}" /etc/localtime
printf '%s\n' "${WSL_TIMEZONE}" | sudo tee /etc/timezone > /dev/null

echo -e "[INFO] timezone 설정 확인"
date

echo ""

echo -e "[INFO] \"${WSL_LOCALE}\" language 설정"
sudo sed -i \
  -e "s|^# ${WSL_LOCALE} UTF-8|${WSL_LOCALE} UTF-8|" \
  /etc/locale.gen
sudo locale-gen
sudo update-locale LANG="${WSL_LOCALE}"

echo -e "[INFO] 시스템 기본 locale '${WSL_LOCALE}' 설정 확인 :: 신규 로그인시 적용됨"
cat /etc/default/locale
echo ""


########## Increase inotify limits ##########
# Increase inotify limits to prevent "failed to create fsnotify watcher: too many open files" errors.
# This is essential for tools that monitor many files, such as Kubernetes (Kind),
# 'kubectl logs -f', and various development watch modes.

echo -e "[INFO] 'failed to create fsnotify watcher: too many open files' 에러 방지를 위해 inotify limits 상향"

echo "fs.inotify.max_user_instances=1024" | sudo tee -a /etc/sysctl.conf
echo "fs.inotify.max_user_watches=524288" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

echo ""
echo -e "##########  WSL2 Ubuntu 24.04 최초 설정 :: END --> WSL 재부팅 필요 ##########"
