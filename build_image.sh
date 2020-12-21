#!/bin/bash
#
set -e
#
ES_TOKEN=
ES_VERSION=
ES_REGISTRY=docker.mariadb.com/es-server
LATEST=10.5
#
function help {
  echo "Usage:"
  echo "${0} --es-version <VERSION> --es-token <TOKEN>"
}
#
function error {
  echo " ==> ERROR: ${@}"
}
#
[[ ${#} -lt 4 ]] && help && exit 1
#
cd $(dirname ${0})
#
while [[ ${#} -gt 0 ]]; do
  case ${1} in
    --es-version)
      ES_VERSION=${2}
      shift 2
    ;;
    --es-token)
      ES_TOKEN=${2}
      shift 2
    ;;
    --es-registry)
      ES_REGISTRY=${2}
      shift 2
    ;;
    --verbose)
      set -x
    ;;
    *)
      error "Wrong option ${1}"
      exit 1
    ;;
  esac
done
#
[[ -z ${ES_TOKEN:-} ]] && error "TOKEN is not specified!" && help
[[ -z ${ES_VERSION:-} ]] && error "VERSION is not specified!" && help
#
docker build --no-cache -t ${ES_REGISTRY}:${ES_VERSION} \
    --build-arg ES_TOKEN=${ES_TOKEN} \
    --build-arg ES_VERSION=${ES_VERSION} \
    -f Dockerfile .
#
if [[ ${ES_VERSION} = ${LATEST} ]]; then
  docker tag ${ES_REGISTRY}:${ES_VERSION} ${ES_REGISTRY}:latest
fi
#
