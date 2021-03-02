#!/bin/bash
#
# Copyright (c) 2020, MariaDB Corporation. All rights reserved.
#
set -e
#
[[ ${IMAGEDEBUG:-0} -eq 1 ]] && set -x
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
[[ ${MARIADB_ALLOW_EMPTY_PASSWORD:-0} -eq 1 ]] && MARIADB_ROOT_PASSWORD=EMPTY
#
MARIADB_INITDB_TZINFO=${MARIADB_INITDB_TZINFO:-1}
[[ ${MARIADB_INITDB_SKIP_TZINFO:-0} -eq 1 ]] && MARIADB_INITDB_TZINFO=0
#
MARIADB_DB=mysql
MARIADB_SYSUSER=mysql
#
MARIADB_CLIENT=mariadb
MARIADB_SERVER=mariadbd
MDB_INSTALL_DB=mariadb-install-db
MDB_TZINFOTOSQL=mariadb-tzinfo-to-sql
#
# Backward compatibility with 10.2 and 10.3
[[ -x "${MARIADB_CLIENT}" ]] || MARIADB_CLIENT=mysql
[[ -x "${MARIADB_SERVER}" ]] || MARIADB_SERVER=mysqld
[[ -x "${MDB_INSTALL_DB}" ]] || MDB_INSTALL_DB=mysql_install_db
[[ -x "${MDB_TZINFOTOSQL}" ]] || MDB_TZINFOTOSQL=mysql_tzinfo_to_sql
#
function message {
  echo "[Init message]: ${@}"
}
#
function error {
  echo >&2 "[Init ERROR]: ${@}"
}
function warning {
  echo >&2 "[Init WARNING]: ${@}"
}
#
function validate_cfg {
  local RES=0
  local CMD="exec gosu ${MARIADB_SYSUSER} ${@} --verbose --help --log-bin-index=$(mktemp -u)"
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
  "${@}" --verbose --help --log-bin-index="$(mktemp -u)" 2>/dev/null | grep "^$conf " | awk '{ print $2 }'
}
#
if [[ "${1:0:1}" = '-' ]] || [[ -z "${1:0:1}" ]]; then
  set -- ${MARIADB_SERVER} "${@}"
fi
#
message "Preparing ${PRODUCT}..."
#
DATADIR="$(get_cfg_value 'datadir' "$@")"
#
if [[ ! -d "${DATADIR}/${MARIADB_DB}" ]]; then
  message "Initializing database..."
  ${MDB_INSTALL_DB} --auth-root-socket-user=${MARIADB_SYSUSER} --datadir="${DATADIR}" --rpm "${@:2}"
  message 'Database initialized'
fi
chown -R ${MARIADB_SYSUSER}:${MARIADB_SYSUSER} "${DATADIR}"
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
gosu ${MARIADB_SYSUSER} "$@" --skip-networking --socket="${SOCKET}" &
PID="${!}"
mariadb=( ${MARIADB_CLIENT} --protocol=socket -uroot -hlocalhost --socket="${SOCKET}" )

for second in {30..0}; do
  [[ ${second} -eq 0 ]] && error 'MariaDB Enterprise Server failed to start!' &&  exit 1
  if echo 'SELECT 1' | "${mariadb[@]}" &> /dev/null; then
    break
  fi
  message "Bringing up ${PRODUCT}..."
  sleep 1
done
#
if [[ "${MARIADB_INITDB_TZINFO}" -eq 1 ]]; then
  message "Loading TZINFO..."
  ${MDB_TZINFOTOSQL} /usr/share/zoneinfo | "${mariadb[@]}" ${MARIADB_DB}
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
if [[ "${MARIADB_ROOT_PASSWORD}" = EMPTY ]]; then
  warning "=-> Warning! Warning! Warning!"
  warning "EMPTY password is specified for image, your container is insecure!!!"
fi
#
if [[ -n "${MARIADB_DATABASE}" ]]; then
  message "Trying to create database ${MARIADB_DATABASE}"
  echo "CREATE DATABASE IF NOT EXISTS \`${MARIADB_DATABASE}\`" | "${mariadb[@]}"
fi
#
if [[ -n "${MARIADB_USER}" ]] && [[ -n "${MARIADB_PASSWORD}" ]]; then
  message "Trying to create user ${MARIADB_USER} with password set"
  echo "CREATE USER '${MARIADB_USER}'@'%' IDENTIFIED BY '${MARIADB_PASSWORD}';" | "${mariadb[@]}"
  if [[ -n "${MARIADB_DATABASE}" ]]; then
    message "Trying to set all privileges on ${MARIADB_DATABASE} to ${MARIADB_USER}..."
    echo "GRANT ALL ON \`${MARIADB_DATABASE}\`.* TO '${MARIADB_USER}'@'%';" | "${mariadb[@]}"
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
      "${mariadb[@]}" < "${_file}"
      echo
      ;;
    *.sql.gz)
      message "Running compressed SQL file ${_file}"
      zcat "${_file}" | "${mariadb[@]}"
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
  echo "CREATE USER IF NOT EXISTS 'root'@'${MARIADB_ROOT_HOST}' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}';" | "${mariadb[@]}"
  echo "GRANT ALL ON *.* TO 'root'@'${MARIADB_ROOT_HOST}' WITH GRANT OPTION;" | "${mariadb[@]}"
  echo "ALTER USER 'root'@'localhost' IDENTIFIED BY '${MARIADB_ROOT_PASSWORD}'; FLUSH PRIVILEGES;" | "${mariadb[@]}"
fi
#
###
if ! kill -s TERM "${PID}" || ! wait "${PID}"; then
  error "${PRODUCT} init process failed!"
  exit 1
fi
#
# Finally
message "${PRODUCT} is ready for start!"
touch /es-init.completed
# Jemalloc
JEMALLOC_SCRIPT="/usr/bin/jemalloc.sh"
if [[ -f "${JEMALLOC_SCRIPT}" ]] && [[ "${JEMALLOC}" -ne 0 ]]; then
  message "Starting ${PRODUCT} with Jemalloc library..."
  exec "${JEMALLOC_SCRIPT}" gosu ${MARIADB_SYSUSER} "$@" 2>&1 | tee -a /var/log/mariadb-error.log
else
  exec gosu ${MARIADB_SYSUSER} "$@" 2>&1 | tee -a /var/log/mariadb-error.log
fi
