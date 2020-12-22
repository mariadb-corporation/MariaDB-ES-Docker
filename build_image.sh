#!/bin/bash
#
#set -e
#
ES_TOKEN=
ES_VERSION=
ES_REGISTRY=docker.mariadb.com/es-server
LATEST=10.5
PUSH=0
#
TAG_LATEST=0
#
function help {
  echo "Usage:"
  echo "${0} --es-version <VERSION> --es-token <TOKEN>"
}
#
function error {
  echo " ==> ERROR: ${@}"
  exit 1
}
#
[[ ${#} -lt 4 ]] && help && error "Wrong parametres!"
#
cd $(dirname ${0})
#
while [[ ${#} -gt 0 ]]; do
  case ${1} in
    --es-version)
      ES_VERSION=${2}
      [[ ${ES_VERSION} = ${LATEST} ]] && TAG_LATEST=1
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
      shift
    ;;
    --push)
    # use with caution, requires working credentials for docker registry
      PUSH=1
      shift
    ;;
    *)
      error "Wrong option ${1}"
      exit 1
    ;;
  esac
done
#
[[ -z ${ES_TOKEN:-} ]]   && help && error "TOKEN is not specified!"
[[ -z ${ES_VERSION:-} ]] && help && error "VERSION is not specified!"
#
docker build --no-cache -t ${ES_REGISTRY}:${ES_VERSION} \
    --build-arg ES_TOKEN=${ES_TOKEN} \
    --build-arg ES_VERSION=${ES_VERSION} \
    -f Dockerfile .
#
# Run test and additional tagging
CONTAINER=$(docker run -d --rm ${ES_REGISTRY}:${ES_VERSION})
[[ -z ${CONTAINER:-} ]] && error "Unable to start container! Please check the log!"
#
# Give it a time to start
for _sec in {1..60}; do
  sleep ${_sec}
  FULLVERSION=$(docker exec -ti ${CONTAINER} tail -n 1 /var/log/mariadb-error.log | egrep -o '10.[0-9].[0-9]+-[0-9]+')
  [[ -n ${FULLVERSION:-} ]] && break
done
#
[[ -z ${FULLVERSION:-} ]] && error "Unable to determine ES version from launched container!"
docker tag ${ES_REGISTRY}:${ES_VERSION} ${ES_REGISTRY}:${FULLVERSION}
#
[[ ${TAG_LATEST} -eq 1 ]] && docker tag ${ES_REGISTRY}:${FULLVERSION} ${ES_REGISTRY}:latest
#
if [[ ${PUSH} -eq 1 ]]; then
  docker push ${ES_REGISTRY}:${ES_VERSION}
  docker push ${ES_REGISTRY}:${FULLVERSION}
  [[ ${TAG_LATEST} -eq 1 ]] && docker push ${ES_REGISTRY}:latest
fi
#
docker stop ${CONTAINER} ||:




