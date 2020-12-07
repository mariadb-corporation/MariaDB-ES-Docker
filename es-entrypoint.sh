#!/bin/bash
#
# Copyright (c) 2020, MariaDB Corporation. All rights reserved.
#
set -e
#
. /etc/IMAGEINFO
#
PRODUCT="MariaDB Enterprise Server ${ES_VERSION}"
#
INITDBDIR="/es-initdb.d"
# should we preload jemalloc?
JEMALLOC=${JEMALLOC:-0}
# Allowed values are <user-defined password>, RANDOM, EMPTY
MARIADB_ROOT_PASSWORD=${MARIADB_ROOT_PASSWORD:-RANDOM}
#
MARIADB_INITDB_TZINFO=${MARIADB_INITDB_TZINFO:-1}
#
function message {
  echo "[Init message]: ${@}"
}
#
function error {
  echo >&2 "[Init ERROR]: ${@}"
}
#
function validate_cfg {
  local RES=0
  local CMD="exec gosu mysql ${@} --verbose --help --log-bin-index=$(mktemp -u)"
  local OUT=$(${CMD}) || RES=${?}
  if [ ${RES} -ne 0 ]; then
    error "Config validation error, please check your configuration!"
    error "Command failed: ${CMD}"
    error "Error output: ${OUT}"
    exit 1
  fi
}
#
function get_cfg_value {
  local conf="${1}"; shift
  "$@" --verbose --help --log-bin-index="$(mktemp -u)" 2>/dev/null | grep "^$conf " | awk '{ print $2 }'
}
#
if [[ "${1:0:1}" = '-' ]]; then
  set -- mysqld "${@}"
fi
#

message "Preparing ${PRODUCT}..."
#
if [ "${1}" = "mysqld" ]; then
#
  DATADIR="$(get_cfg_value 'datadir' "$@")"
#
  if [[ ! -d "${DATADIR}/mysql" ]]; then
    message "Initializing database..."
    mysql_install_db --auth-root-socket-user=mysql --datadir="${DATADIR}" --rpm "${@:2}"
    message 'Database initialized'
  fi
  chown -R mysql:mysql "${DATADIR}"
#
  message "Searching for custom MariaDB configs in ${INITDBDIR}..."
  CFGS=$(find "${INITDBDIR}" -name '*.cnf')
  if [[ -n "${CFGS}" ]]; then
    cp -vf "${CFGS}" /etc/my.cnf.d/
  fi
#
  message "Validating configuration..."
  validate_cfg "${@}"
  SOCKET="$(get_cfg_value 'socket' "$@")"
  gosu mysql "$@" --skip-networking --socket="${SOCKET}" &
  PID="${!}"
  mysql=( mysql --protocol=socket -uroot -hlocalhost --socket="${SOCKET}" )

  for second in {30..0}; do
    [[ ${second} -eq 0 ]] && error 'MariaDB Enterprise Server failed to start!' &&  exit 1
    if echo 'SELECT 1' | "${mysql[@]}" &> /dev/null; then
      break
    fi
    message 'Bringing up ${PRODUCT}...'
    sleep 1
  done
#
  if [[ "${MARIADB_INITDB_TZINFO}" -eq 1 ]]; then
    message "Loading TZINFO"
    mysql_tzinfo_to_sql /usr/share/zoneinfo | "${mysql[@]}" mysql
  fi
#
  if [[ "${MARIADB_ROOT_PASSWORD}" = RANDOM ]]; then
    MARIADB_ROOT_PASSWORD="'"
    while [[ "${MARIADB_ROOT_PASSWORD}" = *"'"* ]] || [[ "${MARIADB_ROOT_PASSWORD}" = *"\\"* ]]; do
      export MARIADB_ROOT_PASSWORD="$(dd if=/dev/urandom bs=1 count=32 2>/dev/null | base64)"
    done
    message "=-> GENERATED ROOT PASSWORD: ${MARIADB_ROOT_PASSWORD}"
  fi
#
  if [[ -n "${MARIADB_DATABASE}" ]]; then
    message "Trying to create database ${MARIADB_DATABASE}"
    echo "CREATE DATABASE IF NOT EXISTS '${MARIADB_DATABASE}'" | "${mysql[@]}"
  fi
#
  if [[ -n "${MARIADB_USER}" ]] && [[ -n "${MARIADB_PASSWORD}" ]]; then
    message "Trying to create user ${MARIADB_USER} with password set"
    echo "CREATE USER '${MARIADB_USER}'@'%' IDENTIFIED BY '${MARIADB_PASSWORD}';" | "${mysql[@]}"
    if [[ -n "${MARIADB_DATABASE}" ]]; then
      message "Trying to set all privileges on ${MARIADB_DATABASE} to ${MARIADB_USER}..."
      echo "GRANT ALL ON '${MARIADB_DATABASE}'.* TO '${MARIADB_USER}'@'%';" | "${mysql[@]}"
    fi
  else
    message "Skipping MariaDB user creation, both MARIADB_USER and MARIADB_PASSWORD must be set"
  fi
#
  for _file in "${INITDBDIR}"/*; do
    case "${_file}" in
      *.sh)
        message "Running shell script ${_file}"
        . "${_file}"
        ;;
      *.sql)
        message "Running SQL file ${_file}"
        "${mysql[@]}" < "${_file}"
        echo
        ;;
      *.sql.gz)
        message "Running compressed SQL file ${_file}"
        zcat "${_file}" | "${mysql[@]}"
        echo
        ;;
      *)
        message "Ignoring ${_file}"
        ;;
    esac
  done
#
# Reading password from docker filesystem (bind-mounted directory or file added during build)
  [[ -z "${MARIADB_ROOT_HOST}" ]] && MARIADB_ROOT_HOST='%'
  [[ -f "${MARIADB_ROOT_PASSWORD}" ]] && MARIADB_ROOT_PASSWORD=$(cat "${MARIADB_ROOT_PASSWORD}")
  if [[ "${MARIADB_ROOT_PASSWORD}" != EMPTY ]]; then
    message "ROOT password has been specified for image, trying to update account..."
    echo "CREATE USER IF NOT EXISTS 'root'@'${MARIADB_ROOT_HOST}' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';" | "${mysql[@]}"
    echo "GRANT ALL ON *.* TO 'root'@'${MARIADB_ROOT_HOST}' WITH GRANT OPTION;" | "${mysql[@]}"
    echo "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}'; FLUSH PRIVILEGES;" | "${mysql[@]}"
  fi
#
###
  if ! kill -s TERM "${PID}" || ! wait "${PID}"; then
    error "${PRODUCT} init process failed!"
    exit 1
  fi
#
fi
#
# Finally
message "${PRODUCT} is ready for start!"
touch /es-init.completed
# Jemalloc
JEMALLOC_SCRIPT="/usr/bin/jemalloc.sh"
if [[ -f "${JEMALLOC_SCRIPT}" ]] && [[ "${JEMALLOC}" -ne 0 ]]; then
  message "Starting ${PRODUCT} with Jemalloc library..."
  exec "${JEMALLOC_SCRIPT}" gosu mysql "$@" 2>&1 | tee -a /var/log/mariadb-error.log
else
  exec gosu mysql "$@" 2>&1 | tee -a /var/log/mariadb-error.log
fi




