#!/bin/bash

# strict 모드 활성화 (오류 발생 시 즉시 중단)
# -E : ERR 트랩을 함수 / 서브셸에서도 상속
# -e : 명령 실행 중 오류(exit code ≠ 0) 발생 시 즉시 종료
# -u : 선언되지 않은 변수를 사용하면 오류로 처리
# -o pipefail : 파이프라인(|) 중간 명령이 실패해도 실패로 인식
set -Eeuo pipefail

#  Extra Util 의 각 실행 파일 설치 경로 -> '~/.local/bin' 의 PATH 등록은 별도 처리 필요
USER_LOCAL_BIN_PATH="${HOME}/.local/bin"

# NodeJS, HuggingFace CLI 등 별도 경로로 설치가 필요한 Extra Util 들의 HOME 내 설치 경로
USER_LOCAL_OPT_PATH="${HOME}/.local/opt"

echo -e "##########  WSL2 Ubuntu 24.04 Extra Util 설치 :: START ##########"
echo ""

########## Install Python 3.13 ##########

# @Reference
# - How To Install Python 3.13 on Ubuntu 24.04|22.04
#   https://computingforgeeks.com/how-to-install-python-on-ubuntu/
#
# Ubuntu 24.04 기본 python3 (3.12) 는 유지하고 python3.13 을 별도로 설치합니다.

echo -e "[INFO] Python 3.13 설치를 위한 deadsnakes PPA 등록 :: START"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  software-properties-common

sudo add-apt-repository -y --no-update ppa:deadsnakes/ppa
sudo apt-get update
echo -e "[INFO] Python 3.13 설치를 위한 deadsnakes PPA 등록 :: END"
echo ""

echo -e "[INFO] Python 3.13 + venv 설치 :: START"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  python3.13 \
  python3.13-venv
echo -e "[INFO] Python 3.13 + venv 설치 :: END"
echo ""

echo -e "[INFO] Ubuntu 24.04 기본 Python3 버전 확인 :: python3 로 실행"
python3 --version

echo -e "[INFO] 별도 설치한 Python 3.13 버전 확인 :: python3.13 으로 실행"
python3.13 --version

echo -e "[INFO] Python 3.13 기반 pip 설치 확인"
python3.13 -m pip --version

echo ""

########## Install OpenJDK 21 based on Eclipse Adoptium Temurin ##########

# @Reference
# - Eclipse Temurin :: Linux (RPM/DEB/APK) installer packages
#   https://adoptium.net/installation/linux/

ADOPTIUM_KEYRING_PATH=/etc/apt/keyrings/adoptium.gpg
ADOPTIUM_APT_SOURCE_PATH=/etc/apt/sources.list.d/adoptium.list
ADOPTIUM_APT_DIST=$(grep '^VERSION_CODENAME=' /etc/os-release | cut -d= -f2)

echo -e "[INFO] Eclipse Adoptium APT 서명 키 등록"
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://packages.adoptium.net/artifactory/api/gpg/key/public \
  | gpg --batch --yes --dearmor \
  | sudo tee "${ADOPTIUM_KEYRING_PATH}" > /dev/null
sudo chmod 0644 "${ADOPTIUM_KEYRING_PATH}"

echo -e "[INFO] Eclipse Adoptium APT '${ADOPTIUM_APT_DIST}' 저장소 등록 :: START"
echo "deb [signed-by=${ADOPTIUM_KEYRING_PATH}] https://packages.adoptium.net/artifactory/deb ${ADOPTIUM_APT_DIST} main" \
  | sudo tee "${ADOPTIUM_APT_SOURCE_PATH}" > /dev/null
sudo apt-get update
echo -e "[INFO] Eclipse Adoptium APT '${ADOPTIUM_APT_DIST}' 저장소 등록 :: END"
echo ""

echo -e "[INFO] Eclipse Adoptium Temurin JDK 21 설치 :: START"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  temurin-21-jdk
echo -e "[INFO] Eclipse Adoptium Temurin JDK 21 설치 :: END"
echo ""

echo -e "[INFO] Temurin JDK 21 설치 확인"
java --version
echo ""

JAVA_HOME_PATH="$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")"
echo "[INFO] JDK 21 전용 JAVA_HOME 경로 :: ${JAVA_HOME_PATH}"

echo ""


########## Install Node.js 22 LTS ##########

# @Reference
# - Node.js LTS releases :: official latest-v<major>.x directory and checksums
#   https://nodejs.org/dist/
# - Bun installation
#   https://bun.sh/docs/installation

case "$(uname -m)" in
  x86_64)
    NODEJS_ARCH=x64
    ;;
  aarch64|arm64)
    NODEJS_ARCH=arm64
    ;;
  *)
    echo "[ERROR] 지원하지 않는 Node.js 아키텍처: $(uname -m)" >&2
    exit 1
    ;;
esac

# NodeJS Major Version
NODEJS_MAJOR_VERSION=22

# latest-v<major>.x 경로는 지정한 메이저 버전의 최신 패치 릴리스를 가리킵니다.
NODEJS_DIST_URL="https://nodejs.org/dist/latest-v${NODEJS_MAJOR_VERSION}.x"
NODEJS_CHECKSUMS_FILE="$(mktemp)"
curl -fsSL -o "${NODEJS_CHECKSUMS_FILE}" "${NODEJS_DIST_URL}/SHASUMS256.txt"

# CHECKSUMS 목록에서 현재 CPU 아키텍쳐에 맞는 Node.js 설치 파일의 이름을 검색합니다.
# -> 해당 파일명에 설치 시점 latest 에 해당하는 버전 정보가 포함되어 있음
NODEJS_ARCHIVE_NAME="$(awk -v major="${NODEJS_MAJOR_VERSION}" -v arch="${NODEJS_ARCH}" \
  '$2 ~ ("^node-v" major "[.][0-9]+[.][0-9]+-linux-" arch "[.]tar[.]xz$") { print $2; exit }' \
  "${NODEJS_CHECKSUMS_FILE}")"
if [[ -z "${NODEJS_ARCHIVE_NAME}" ]]; then
  echo "[ERROR] CHECKSUMS 목록에서 Linux ${NODEJS_ARCH} 전용 Node.js ${NODEJS_MAJOR_VERSION} 파일을 찾지 못했습니다." >&2
  exit 1
fi

# NodeJs 설치 파일명에서 설치 시점 latest 에 해당하는 최신 버전 정보 조회
NODEJS_VERSION="${NODEJS_ARCHIVE_NAME#node-}"
NODEJS_VERSION="${NODEJS_VERSION%%-linux-*}"

echo -e "[INFO] ${NODEJS_DIST_URL} 에서 조회한 Node.js ${NODEJS_MAJOR_VERSION} 최신 버전 :: ${NODEJS_VERSION}"

# CHECKSUMS 목록에서 선택한 NodeJs 설치 파일명에 해당하는 SHA-256 값 조회
NODEJS_ARCHIVE_SHA256="$(awk -v archive="${NODEJS_ARCHIVE_NAME}" \
  '$2 == archive { print $1; exit }' "${NODEJS_CHECKSUMS_FILE}")"
if [[ -z "${NODEJS_ARCHIVE_SHA256}" ]]; then
  echo "[ERROR] '${NODEJS_ARCHIVE_NAME}' Node.js 파일의 SHA-256 값을 찾지 못했습니다: " >&2
  exit 1
fi

# NodeJS 다운로드 URL
NODEJS_ARCHIVE_URL="${NODEJS_DIST_URL}/${NODEJS_ARCHIVE_NAME}"

# NodeJs 다운로드 경로
NODEJS_ARCHIVE_PATH="${HOME}/${NODEJS_ARCHIVE_NAME}"

NODEJS_INSTALL_PATH="${USER_LOCAL_OPT_PATH}/nodejs/${NODEJS_VERSION}-${NODEJS_ARCH}"
NODEJS_BIN_PATH="${USER_LOCAL_BIN_PATH}"

echo -e "[INFO] Node.js ${NODEJS_MAJOR_VERSION} '${NODEJS_ARCHIVE_URL}' 다운로드"
mkdir -p "${NODEJS_INSTALL_PATH}" "${NODEJS_BIN_PATH}"
curl -fsSL -o "${NODEJS_ARCHIVE_PATH}" "${NODEJS_ARCHIVE_URL}"

echo -e "[INFO] Node.js ${NODEJS_MAJOR_VERSION} '${NODEJS_ARCHIVE_PATH}' 다운로드 결과"
ls -al "${NODEJS_ARCHIVE_PATH}"

# 다운로드한 Node.js 바이너리가 SHA-256 값과 일치하는지 검증
if ! printf '%s  %s\n' "${NODEJS_ARCHIVE_SHA256}" "${NODEJS_ARCHIVE_PATH}" | sha256sum --check --status; then
  echo "[ERROR] Node.js ${NODEJS_MAJOR_VERSION} 다운로드 파일 '${NODEJS_ARCHIVE_PATH}' 의 SHA-256 검증에 실패했습니다." >&2
  exit 1
fi
echo -e "[INFO] Node.js ${NODEJS_MAJOR_VERSION} 다운로드 파일 '${NODEJS_ARCHIVE_PATH}' 의 SHA-256 검증 성공"

echo -e "[INFO] '${NODEJS_INSTALL_PATH}' 에 Node.js ${NODEJS_MAJOR_VERSION} 압축 해제"
tar -xJf "${NODEJS_ARCHIVE_PATH}" -C "${NODEJS_INSTALL_PATH}" --strip-components=1

# node, npm, npx 를 ${NODEJS_BIN_PATH} 에 link
ln -sfn "${NODEJS_INSTALL_PATH}/bin/node" "${NODEJS_BIN_PATH}/node"
ln -sfn "${NODEJS_INSTALL_PATH}/bin/npm" "${NODEJS_BIN_PATH}/npm"
ln -sfn "${NODEJS_INSTALL_PATH}/bin/npx" "${NODEJS_BIN_PATH}/npx"

echo ""

echo -e "[INFO] Node.js ${NODEJS_MAJOR_VERSION} 설치 확인"
"${NODEJS_BIN_PATH}/node" --version

echo -e "[INFO] Node.js ${NODEJS_MAJOR_VERSION} npm 설치 확인"
PATH="${NODEJS_BIN_PATH}:${PATH}" "${NODEJS_BIN_PATH}/npm" --version

rm -f "${NODEJS_CHECKSUMS_FILE}"
rm -f "${NODEJS_ARCHIVE_PATH}"

echo ""


########## Install Azure CLI ##########

# @Reference
# - Install the Azure CLI on Linux
#   https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux?view=azure-cli-latest&pivots=apt

echo -e "[INFO] Microsoft APT 서명 키 등록"
sudo mkdir -p /etc/apt/keyrings
curl -sLS https://packages.microsoft.com/keys/microsoft.asc |
  gpg --batch --yes --dearmor | sudo tee /etc/apt/keyrings/microsoft.gpg > /dev/null
sudo chmod go+r /etc/apt/keyrings/microsoft.gpg

AZ_DIST=$(grep '^VERSION_CODENAME=' /etc/os-release | cut -d= -f2)
echo -e "[INFO] Microsoft Azure CLI APT '${AZ_DIST}' 저장소 등록 :: START"
echo "Types: deb
URIs: https://packages.microsoft.com/repos/azure-cli/
Suites: ${AZ_DIST}
Components: main
Architectures: $(dpkg --print-architecture)
Signed-by: /etc/apt/keyrings/microsoft.gpg" | sudo tee /etc/apt/sources.list.d/azure-cli.sources

sudo apt-get update
echo -e "[INFO] Microsoft Azure CLI APT '${AZ_DIST}' 저장소 등록 :: END"
echo ""

echo -e "[INFO] Azure CLI 설치 :: START"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  azure-cli
echo -e "[INFO] Azure CLI 설치 :: END"
echo ""

echo -e "[INFO] Azure CLI 설치 확인"
az version
echo ""

# 'AZURE_BICEP_USE_BINARY_FROM_PATH=True' -> Azure CLI 가 PATH 에 지정된 Bicep 바이너리를 사용하도록 설정
AZURE_BICEP_BASHRC_LINE='export AZURE_BICEP_USE_BINARY_FROM_PATH=True'

if ! grep -Fxq "${AZURE_BICEP_BASHRC_LINE}" "${HOME}/.bashrc"; then
  printf '\n%s\n' "${AZURE_BICEP_BASHRC_LINE}" >> "${HOME}/.bashrc"
  echo "[INFO] ~/.bashrc 에 'AZURE_BICEP_USE_BINARY_FROM_PATH=True 설정' 추가"
else
  echo "- ~/.bashrc 에 'AZURE_BICEP_USE_BINARY_FROM_PATH=True' 설정이 이미 있습니다."
fi

echo ""


########## Install Bicep ##########

# @Reference   https://github.com/Azure/bicep/releases
#              https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/install
# @Version     Latest

BICEP_DOWNLOAD_URL=https://github.com/Azure/bicep/releases/latest/download/bicep-linux-x64

curl -G --silent -f \
    -o "${HOME}"/bicep \
    --location "${BICEP_DOWNLOAD_URL}"

chmod +x "${HOME}"/bicep

install -m 0755 "${HOME}"/bicep "${USER_LOCAL_BIN_PATH}/bicep"
rm -f "${HOME}"/bicep

echo -e "[INFO] bicep 설치 확인"
"${USER_LOCAL_BIN_PATH}/bicep" --version

echo ""


########## Install KinD ##########

# @Reference   https://kind.sigs.k8s.io/
#              https://github.com/kubernetes-sigs/kind/releases
# @Download    https://github.com/kubernetes-sigs/kind/releases/latest/download/kind-linux-amd64
# @Version     Latest

KIND_DOWNLOAD_URL=https://github.com/kubernetes-sigs/kind/releases/latest/download/kind-linux-amd64

curl -G --silent -f \
  -o "${HOME}"/kind \
  --location "${KIND_DOWNLOAD_URL}"

chmod +x "${HOME}"/kind
mkdir -p "${USER_LOCAL_BIN_PATH}"
install -m 0755 "${HOME}"/kind "${USER_LOCAL_BIN_PATH}/kind"
rm -f "${HOME}"/kind

echo -e "[INFO] kind 설치 확인"
"${USER_LOCAL_BIN_PATH}/kind" --version

# 'KIND_EXPERIMENTAL_PROVIDER=podman' -> Kind 가 Podman provider 를 사용하도록 설정
KIND_PROVIDER_BASHRC_LINE='export KIND_EXPERIMENTAL_PROVIDER=podman'

if ! grep -Fxq "${KIND_PROVIDER_BASHRC_LINE}" "${HOME}/.bashrc"; then
  printf '\n%s\n' "${KIND_PROVIDER_BASHRC_LINE}" >> "${HOME}/.bashrc"
  echo "[INFO] ~/.bashrc 에 'KIND_EXPERIMENTAL_PROVIDER=podman' 설정 추가"
else
  echo "- ~/.bashrc 에 'KIND_EXPERIMENTAL_PROVIDER=podman' 설정이 이미 있습니다."
fi

echo ""


########## Install kubectl ##########

# @Reference   https://kubernetes.io/releases/
#              https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
# @Download    https://dl.k8s.io/release/stable.txt 에서 최신 stable 버전 조회 후 kubectl 다운로드
# @Version     Latest stable release

KUBECTL_STABLE_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)

curl -G --silent -f \
  -o "${HOME}"/kubectl \
  -L "https://dl.k8s.io/release/${KUBECTL_STABLE_VERSION}/bin/linux/amd64/kubectl"

chmod +x "${HOME}"/kubectl
install -m 0755 "${HOME}"/kubectl "${USER_LOCAL_BIN_PATH}/kubectl"

echo -e "[INFO] kubectl 설치 확인"
"${USER_LOCAL_BIN_PATH}/kubectl" version --client

rm -f "${HOME}"/kubectl

echo ""


########## Install Helm 3 ##########

# @Reference   https://github.com/helm/helm/releases/
#              https://helm.sh/docs/intro/install/
# @Version     Latest Helm 3 release

HELM_3_LATEST_VERSION_URL=https://get.helm.sh/helm3-latest-version
HELM_3_VERSION="$(curl -G --silent -f --show-error \
  --data-urlencode "ts=$(date +%s)" \
  "${HELM_3_LATEST_VERSION_URL}")"

if ! [[ "${HELM_3_VERSION}" =~ ^v3\.[0-9]+\.[0-9]+$ ]]; then
  echo "[ERROR] ${HELM_3_LATEST_VERSION_URL} 에서 최신 Helm 3 버전 조회 실패 :: 조회 value '${HELM_3_VERSION}'" >&2
  exit 1
fi

echo "[INFO] ${HELM_3_LATEST_VERSION_URL} 에서 조회한 Helm 3 최신 버전 :: ${HELM_3_VERSION}"
HELM_3_DOWNLOAD_URL=https://get.helm.sh/helm-${HELM_3_VERSION}-linux-amd64.tar.gz

curl -G --silent -f \
    -o "${HOME}"/helm-v3.tar.gz \
    --location "${HELM_3_DOWNLOAD_URL}"

tar -zxf "${HOME}"/helm-v3.tar.gz \
    -C "${HOME}"/

chmod +x "${HOME}"/linux-amd64/helm
install -m 0755 "${HOME}"/linux-amd64/helm "${USER_LOCAL_BIN_PATH}/helm"

echo -e "[INFO] helm 3 설치 확인"
"${USER_LOCAL_BIN_PATH}/helm" version

rm -rf "${HOME}"/linux-amd64
rm -f "${HOME}"/helm-v3.tar.gz

echo ""


########## Install OpenCode ##########

# @Reference   https://github.com/anomalyco/opencode/releases
#              https://opencode.ai/install

case "$(uname -m)" in
  x86_64)
    OPENCODE_TARGET=linux-x64
    ;;
  aarch64|arm64)
    OPENCODE_TARGET=linux-arm64
    ;;
  *)
    echo "[ERROR] 지원하지 않는 OpenCode 아키텍처: $(uname -m)" >&2
    exit 1
    ;;
esac

OPENCODE_DOWNLOAD_URL="https://github.com/anomalyco/opencode/releases/latest/download/opencode-${OPENCODE_TARGET}.tar.gz"
OPENCODE_BIN_PATH="${USER_LOCAL_BIN_PATH}"

mkdir -p "${OPENCODE_BIN_PATH}"

curl -G --silent -f \
  -o "${HOME}"/opencode.tar.gz \
  --location "${OPENCODE_DOWNLOAD_URL}"

tar -xzf "${HOME}"/opencode.tar.gz \
  -C "${HOME}"/

chmod +x "${HOME}"/opencode
mv "${HOME}"/opencode "${OPENCODE_BIN_PATH}"/opencode

echo -e "[INFO] OpenCode 설치 확인"
"${OPENCODE_BIN_PATH}"/opencode --version

# CleanUp
rm -f "${HOME}"/opencode.tar.gz

echo ""


########## Install Codex CLI ##########

# @Reference
# - OpenAI Codex CLI :: Standalone installer
#   https://github.com/openai/codex

curl --fail --silent --show-error \
  --location https://chatgpt.com/codex/install.sh \
  | CODEX_NON_INTERACTIVE=1 CODEX_INSTALL_DIR="${USER_LOCAL_BIN_PATH}" sh

echo -e "[INFO] Codex CLI 설치 확인"
"${USER_LOCAL_BIN_PATH}"/codex --version

echo ""


########## Install NVIDIA Container Toolkit ##########

# [Reference]
# - Installing the NVIDIA Container Toolkit :: With apt: Ubuntu, Debian
#   https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html#with-apt-ubuntu-debian

# Configure the production repository
echo -e "[INFO] NVIDIA Container Toolkit APT 서명 키 등록"
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
  | sudo gpg --batch --yes --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

echo -e "[INFO] NVIDIA Container Toolkit APT 저장소 등록 :: START"
curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
  | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
  | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
echo -e "[INFO] NVIDIA Container Toolkit APT 저장소 등록 :: END"
echo ""

# Update the packages list from the repository
echo -e "[INFO] NVIDIA Container Toolkit 저장소 패키지 목록 갱신 :: START"
sudo apt-get update
echo -e "[INFO] NVIDIA Container Toolkit 저장소 패키지 목록 갱신 :: END"
echo ""

# NVIDIA Container Toolkit APT 저장소의 stable 채널에서 최신 패키지 버전을 조회합니다.
NVIDIA_CONTAINER_TOOLKIT_VERSION="$(apt-cache madison nvidia-container-toolkit | awk '{ print $3 }' | sort -V | tail -n 1)"
if [[ -z "${NVIDIA_CONTAINER_TOOLKIT_VERSION}" ]]; then
  echo "[ERROR] APT 저장소에서 NVIDIA Container Toolkit 버전을 찾지 못했습니다." >&2
  exit 1
fi

echo "[INFO]  NVIDIA Container Toolkit APT 저장소의 stable 채널에서 조회한 최신 버전 :: ${NVIDIA_CONTAINER_TOOLKIT_VERSION}"

echo -e "[INFO] NVIDIA Container Toolkit 설치 :: START"
sudo apt-get install -y \
    nvidia-container-toolkit="${NVIDIA_CONTAINER_TOOLKIT_VERSION}" \
    nvidia-container-toolkit-base="${NVIDIA_CONTAINER_TOOLKIT_VERSION}" \
    libnvidia-container-tools="${NVIDIA_CONTAINER_TOOLKIT_VERSION}" \
    libnvidia-container1="${NVIDIA_CONTAINER_TOOLKIT_VERSION}"
echo -e "[INFO] NVIDIA Container Toolkit 설치 :: END"
echo ""

echo -e "[INFO] NVIDIA Container Toolkit 버전 확인"
nvidia-ctk --version 2>&1
# Console Output :: "NVIDIA Container Toolkit CLI version (최신 version 정보)"

echo ""


########## Generate NVIDIA Container Device Interface (CDI) Specification ##########

# [Reference]
# - Support for Container Device Interface
#   https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/cdi-support.html
# - cncf-tags/container-device-interface
#   https://github.com/cncf-tags/container-device-interface

sudo mkdir -p /etc/cdi

echo -e "[INFO] NVIDIA Container Device Interface (CDI) 설정 생성 :: START"
sudo nvidia-ctk cdi generate --output=/etc/cdi/nvidia.yaml 2>&1
echo -e "[INFO] NVIDIA Container Device Interface (CDI) 설정 생성 :: END"
echo ""

echo -e "[INFO] NVIDIA Container Toolkit 에서 사용 가능한 CDI 장치 목록 조회"
nvidia-ctk cdi list 2>&1

echo ""


########## Install HuggingFace CLI ##########

# [Reference]
# - Hugging Face :: Command Line Interface (CLI)
#   https://huggingface.co/docs/huggingface_hub/guides/cli
# - hf.co/cli/install.sh

HF_CLI_PATH="${USER_LOCAL_OPT_PATH}/huggingface-cli"
HF_VENV_PATH="${HF_CLI_PATH}/venv"
HF_BIN_PATH="${USER_LOCAL_BIN_PATH}"

mkdir -p "$HF_CLI_PATH" "${HF_BIN_PATH}"

python3 -m venv "${HF_VENV_PATH}"
"${HF_VENV_PATH}/bin/python" -m pip install --quiet --upgrade huggingface_hub

ln -sf "${HF_VENV_PATH}/bin/hf" "${HF_BIN_PATH}/hf"
ln -sf "${HF_VENV_PATH}/bin/huggingface-cli" "${HF_BIN_PATH}/huggingface-cli"

echo -e "[INFO] HuggingFace CLI 설치 확인"
"${HF_BIN_PATH}"/hf --version 2>&1

echo ""


########## Clean Up ##########

echo -e "[INFO] APT 정리"
sudo apt-get clean
sudo rm -rf /var/lib/apt/lists/*

echo ""
echo -e "##########  WSL2 Ubuntu 24.04 Extra Util 설치 :: END ##########"
