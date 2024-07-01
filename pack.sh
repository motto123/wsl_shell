#!/usr/bin/env bash

# 需要下载node(最新版,不要用apt下载(https://nodejs.org/en/download/package-manager),
# jq,unzip,zip,bc,docker engine(v25)

start_time=$(date +%s)

ROOT_PATH=$(pwd)
META_PATH="${ROOT_PATH}/meta.json"
PROJECT_DIR="${ROOT_PATH}/com.byd.filemange"
PACK_DIR="${ROOT_PATH}/dist"
PACK_FILE=packfile.cap
PLATFORM=linux/amd64
LOG_PATH=${ROOT_PATH}/log.log
PACKAGE_COUNT=0
FINIAL_PACKAGE_COUNT=6

# all command tools are installed
function ready() {
  #  ping -c 1 baidu.com >/dev/null 2>&1
  #  if [ ! $? -eq 0 ]; then
  #    echo "No internet connection."
  #  fi

  str="$(docker -v)"
  if [ ! $? -eq 0 ]; then
    echo "docker engine not running"
    exit 1
  fi
  # shellcheck disable=SC2076
  if [[ ! $str =~ "25." ]]; then
    echo "docker engine version must be 25"
  fi

  jq --version >/dev/null
  if [ ! $? -eq 0 ]; then
    echo "jq not installed"
    exit 1
  fi

  unzip -v >/dev/null
  if [ ! $? -eq 0 ]; then
    echo "unzip not installed"
    exit 1
  fi
  zip -v >/dev/null
  if [ ! $? -eq 0 ]; then
    echo "zip not installed"
    exit 1
  fi
  bc --version >/dev/null
  if [ ! $? -eq 0 ]; then
    echo "bc not installed"
    exit 1
  fi
  pnpm -v >/dev/null
  if [ ! $? -eq 0 ]; then
    echo "pnpm not installed"
    exit 1
  fi
  git --version >/dev/null
  if [ ! $? -eq 0 ]; then
    echo "git not installed"
    exit 1
  fi
  npm -v >/dev/null
  if [ ! $? -eq 0 ]; then
    echo "npm not installed"
    exit 1
  fi
  node -v >/dev/null
  if [ ! $? -eq 0 ]; then
    echo "node not installed"
    exit 1
  fi
}

function clean() {
  rm -rf "${PROJECT_DIR}" 2>/dev/null
  rm -rf "${PACK_DIR}" 2>/dev/null
  rm "packfile/${PACK_FILE}" 2>/dev/null
  rm -f "${META_PATH}" 2>/dev/null
  rm -f "${ROOT_PATH}"/packfile/components/*.ca
  docker image prune -f >/dev/null

}

function init() {
  ready
  clean
  if [ ! -d "${PROJECT_DIR}" ]; then
    git clone https://kgit.wpsit.cn/code/202404/com.byd.filemange.git ${PROJECT_DIR}
  fi
  mkdir "${PACK_DIR}"
}

function buildSrv() {
  IMAGE_NAME=$1
  IMAGE_TAG=$2
  if [[ -z $(docker images | grep 'filetemplatesrv_init' | awk -F ' ' '{print $1}') ]]; then
    docker build -f Dockerfile_mine_init . -t filetemplatesrv_init:0.0.1
  fi
  docker build --no-cache -f Dockerfile_mine --platform=${PLATFORM} . -t ${IMAGE_NAME}:${IMAGE_TAG}
  # docker build --no-cache -f Dockerfile --platform=${PLATFORM} . -t ${IMAGE_NAME}:${IMAGE_TAG}

  timestamp=$(docker inspect -f '{{.Created}}' ${IMAGE_NAME}:${IMAGE_TAG} | xargs -I{} date -d {} +%s)
  if [ "$(expr "$timestamp" + 1)" -lt "$(date +%s)" ]; then
    echo "build ${IMAGE_NAME}:${IMAGE_TAG} failed, because the image has no update, created: $(date -d @$timestamp '+%Y:%m:%d %H:%M:%S')"
    exit 1
  fi
  cd "${PACK_DIR}" || exit
  docker save -o service-${IMAGE_NAME}-${IMAGE_TAG} ${IMAGE_NAME}:${IMAGE_TAG}
  cp "${META_PATH}" "meta.json"
  zip ${IMAGE_NAME}.ca "meta.json" "service-${IMAGE_NAME}-${IMAGE_TAG}"
  rm -f "meta.json"
}

function recordLogsForCurrentDay() {
  git log --since="midnight" --until="now" --format="%s" |
    grep -v -e 'Merge branch' -e 'Merge remote-tracking branch' -e 'debug' -e 'Debug' >>"${LOG_PATH}"
}

function packSvr() {
  APP_ID=""
  IMAGE_NAME=""
  NAME=""
  TYPE=""
  IMAGE_TAG=""

  Json_Str=$(cat "$ROOT_PATH/packfile/components/$1")
  keys=$(echo "$Json_Str" | jq -r 'keys[]')
  for key in $keys; do
    value=$(echo "$Json_Str" | jq -r ".$key")
    #    echo "Key: $key, Value: $value"
    if [ "$key" == "appId" ]; then
      APP_ID=$value
    elif [ "$key" == "id" ]; then
      IMAGE_NAME="$value"
    elif [ "$key" == "name" ]; then
      NAME="$value"
    elif [ "$key" == "type" ]; then
      TYPE="$value"
    elif [ "$key" == "version" ]; then
      IMAGE_TAG="$value"
    fi
  done

  # echo "APP_ID: $APP_ID, IMAGE_NAME: $IMAGE_NAME, NAME: $NAME, TYPE: $TYPE, VERSION: $VERSION"
  cat <<EOT >"${META_PATH}"
{
  "appId": "${APP_ID}",
  "id": "${IMAGE_NAME}",
  "name": "${NAME}",
  "version": "${IMAGE_TAG}",
  "type": "${TYPE}",
  "source": "file://service-${IMAGE_NAME}-${IMAGE_TAG}",
  "internal": false
}
EOT
  #  cat "${META_PATH}"

  buildSrv "$IMAGE_NAME" "$IMAGE_TAG"
  rm "$META_PATH"
  cp "${ROOT_PATH}/dist/${IMAGE_NAME}.ca" "${ROOT_PATH}/packfile/components"
}

function packFileTemplateSvr() {
  cd "$PROJECT_DIR" || exit
  git checkout .
  git checkout liuyu/feat_file_template
  # git checkout feat_file_template_version_extension
  git pull
  recordLogsForCurrentDay
  cd filetemplatesrv || exit
  packSvr "filetemplatesrv.json"
  if [ ! $? -ne 0 ]; then
    echo -e "======================pack filetemplatesrv successful======================\n" >>"${LOG_PATH}"
    ((PACKAGE_COUNT += 1))
  fi
}

function packFileReviewSvr() {
  cd "$PROJECT_DIR" || exit
  git checkout .
  git checkout dev_filereviewsvr
  git pull

  recordLogsForCurrentDay
  cd filereviewsvr || exit
  packSvr "filereviewsvr.json"
  if [ ! $? -ne 0 ]; then
    echo -e "======================pack filereviewsvr successful======================\n" >>"${LOG_PATH}"
    ((PACKAGE_COUNT += 1))
  fi
}

function packFileTemplateFe() {
  cd "$PROJECT_DIR" || exit
  git checkout .
  git checkout feat_file_template
  git pull

  recordLogsForCurrentDay
  cd fileTemplatefe/src/apps/template || exit
  bash build.sh
  cp dist/plugin.ca "${ROOT_PATH}/packfile/components/filetemplatefe.ca"
  if [ ! $? -ne 0 ]; then
    echo -e "======================pack filetemplatefe successful======================\n" >>"${LOG_PATH}"
    ((PACKAGE_COUNT += 1))
  fi
}

function packFileReviewFe() {
  cd "$PROJECT_DIR" || exit
  git checkout .
  git checkout dev_filereview_frontend_20240615
  git pull

  recordLogsForCurrentDay
  cd fileReviewfe/src/apps/fileReviewKdocs || exit
  bash build.sh
  cp dist/plugin.ca "${ROOT_PATH}/packfile/components/filereviewfe.ca"
  if [ ! $? -ne 0 ]; then
    echo -e "======================pack filereviewfe successful======================\n" >>"${LOG_PATH}"
    ((PACKAGE_COUNT += 1))
  fi
}

function packAdminFileReview() {
  cd "$PROJECT_DIR" || exit
  git checkout .
  git checkout dev_filereview_frontend_20240615
  git pull

  # recordLogsForCurrentDay
  cd fileReviewfe/src/apps/fileViewManagement || exit
  bash build.sh
  cp dist/plugin.ca "${ROOT_PATH}/packfile/components/adminfilereview.ca"
  if [ ! $? -ne 0 ]; then
    echo -e "======================pack adminfilereview successful======================\n" >>"${LOG_PATH}"
    ((PACKAGE_COUNT += 1))
  fi
}

function packWoFileReview() {
  cd "${PROJECT_DIR}" || exit
  git checkout .
  git checkout dev_filereview_frontend_20240615
  git pull

  # recordLogsForCurrentDay
  cd fileReviewfe/src/apps/woFileReview || exit

  bash build.sh
  cp dist/plugin.ca "${ROOT_PATH}/packfile/components/wofilereview.ca"
  if [ ! $? -ne 0 ]; then
    echo -e "======================pack wofilereview successful======================\n" >>"${LOG_PATH}"
    ((PACKAGE_COUNT += 1))
  fi
}

pack() {
  rm -rf "${LOG_PATH}" 2>/dev/null

  echo "======================start packFileTemplateSvr======================"
  packFileTemplateSvr

  echo "======================start packFileReviewSvr======================"
  packFileReviewSvr

  echo "======================start packFileTemplateFe======================"
  packFileTemplateFe

  echo "======================start packFileReviewFe======================"
  packFileReviewFe

  echo "======================start packAdminFileReview======================"
  packAdminFileReview

  echo "======================start packWoFileReview======================"
  packWoFileReview

  if [ ! ${PACKAGE_COUNT} -eq ${FINIAL_PACKAGE_COUNT} ]; then
    echo "pack failed, package count is ${PACKAGE_COUNT}, package count should be ${FINIAL_PACKAGE_COUNT}"
    exit 1
  fi

  echo "======================start zip packfile======================"

  cd "${ROOT_PATH}" || exit
  rm -f "${PACK_FILE}" 2>/dev/null
  cd "packfile" || exit
  zip -r "${PACK_FILE}" ./*
  rm "/mnt/c/${PACK_FILE}" 2>/dev/null
  cp "${PACK_FILE}" "/mnt/c/" 2>/dev/null
  cp ${PACK_FILE} tmp.zip
  echo "======================end zip packfile======================"
  unzip -lv tmp.zip | grep components | grep .ca | awk -F ' ' '{print $8 "  " $1 ","}' | tee -a "${LOG_PATH}"
  ls -lh ${PACK_FILE} | awk -F ' ' '{print $9" "$5}' | tee -a "${LOG_PATH}"

  rm tmp.zip
  mv "${PACK_FILE}" "${ROOT_PATH}"
  echo -e "\npack success, package count: ${PACKAGE_COUNT}\n" | tee -a "${LOG_PATH}"
}

help() {
  echo "Usage: $(basename "$0") [options]"
  echo "Options:"
  echo "  --clean        	 clean up temporary files"
}

# Parse command-line options
while [[ $# -gt 0 ]]; do
  case "$1" in
  --help)
    help
    exit 0
    ;;
  --ready)
    ready
    exit 0
    ;;
  --clean)
    clean
    exit 0
    ;;
  *)
    # echo ""
    ;;
  esac
  shift
done

init
pack
clean

echo "Time taken: $(($(date +%s) - start_time))s" | tee -a "${LOG_PATH}"
echo "current time: $(date '+%Y:%m:%d %H:%M:%S')" | tee -a "${LOG_PATH}"
