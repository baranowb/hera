#!/bin/bash
set -eo pipefail
readonly HARMONIA_HOME=${HARMONIA_HOME:-"${WORKSPACE}/harmonia/"}
readonly HARMONIA_DEBUG=${HARMONIA_DEBUG}
readonly BUILD_COMMAND=${BUILD_COMMAND}
readonly PARENT_JOB_DIR=${PARENT_JOB_DIR:-'/parent_job/'}
readonly PARENT_CORE_JOB_DIR=PARENT_CORE_JOB_DIR:-'/parent_core_job/'}
readonly HARMONIA_SCRIPT=${HARMONIA_SCRIPT}
readonly BUILD_ID=${BUILD_ID}
readonly JOB_NAME=${JOB_NAME}
readonly PRINT_BUILD_ENV=${PRINT_BUILD_ENV:-'true'}
readonly MAVEN_VERBOSE=${MAVEN_VERBOSE}
readonly MAVEN_SETTINGS_XML=${MAVEN_SETTINGS_XML:-'/opt/tools/settings.xml'}
readonly MAVEN_GOALS=${MAVEN_GOALS:-'clean install'}
set -u

readonly HOSTNAME=${HOSTNAME:-'localhost'}
export HOSTNAME
export USER='jenkins'
readonly HERA_HOME=${HERA_HOME:-"${WORKSPACE}/hera/"}
readonly FAIL_TO_SET_DEFAULT_TO_WORKSPACE_CODE='13'
readonly COPY_ARTIFACTS=${COPY_ARTIFACTS:-$(if [[ "${BUILD_COMMAND}" = "testsuite" ]]; then echo "true"; fi)}

echo "WORKSPACE: ${WORKSPACE}"
echo "HERA_HOME: ${HERA_HOME}"

# shellcheck source=./library.sh
source "${HERA_HOME}/library.sh"

printJobConfig
printEnv

for var in "${HERA_HOME}" "${WORKSPACE}"
do
  is_defined "${var}" 'One of the HOME value or WORKSPACE is undefined'
  is_dir "${var}" 'One of the HOME or the WORKSPACE is not a dir'
done
is_defined "${JOB_NAME}" 'No BUILD_NAME provided'
is_defined "${BUILD_ID}" 'No BUILD_ID provided'

# harmonia based jobs
if [ -n "${HARMONIA_SCRIPT}" ]; then
  WORKSPACE="${WORKSPACE}/workdir"
  cd "${WORKSPACE}" || exit "${FAIL_TO_SET_DEFAULT_TO_WORKSPACE_CODE}"

  is_defined "${HARMONIA_HOME}" 'HARMONIA_HOME is undefined'
  is_dir "${HARMONIA_HOME}" "Provided HARMONIA_HOME is invalid: ${HARMONIA_HOME}"

  if [ "${COPY_ARTIFACTS}" = 'true' ]; then
    is_dir "${PARENT_JOB_DIR}"
    copy_artefact_from_parent_job "${PARENT_JOB_DIR}/workdir" "${WORKSPACE}"
  fi

  if [ "${HARMONIA_DEBUG}" ]; then
    # shellcheck disable=SC2086
    bash -x "${HARMONIA_HOME}/${HARMONIA_SCRIPT}" ${BUILD_COMMAND} 2>&1 | tee "${HERA_HOME}/build_${BUILD_ID}.log"
  else
    # shellcheck disable=SC2086
    "${HARMONIA_HOME}/${HARMONIA_SCRIPT}" ${BUILD_COMMAND} 2>&1 | tee "${HERA_HOME}/build_${BUILD_ID}.log"
  fi
else
  cd "${WORKSPACE}" || exit "${FAIL_TO_SET_DEFAULT_TO_WORKSPACE_CODE}"
  # pure maven based jobs
  if [ -n "${MAVEN_SETTINGS_XML}" ]; then
    readonly MAVEN_SETTINGS_OPT="-s ${MAVEN_SETTINGS_XML}"
  else
    readonly MAVEN_SETTINGS_OPT=""
  fi

  echo '==== Executing Maven ==='
  echo "Current dir: $(pwd)"
  echo "Cmd: # ${MAVEN_HOME}/bin/mvn ${MAVEN_SETTINGS_OPT} ${MAVEN_OPTS} ${MAVEN_GOALS}"
  # shellcheck disable=SC2086
  ${MAVEN_HOME}/bin/mvn ${MAVEN_SETTINGS_OPT} ${MAVEN_OPTS} ${MAVEN_GOALS}
  echo '==== Executing Maven done ==='
fi

readonly BUILD_STATUS="${PIPESTATUS[0]}"
echo "${BUILD_STATUS}" > "${HERA_HOME}/build_${BUILD_ID}_${BUILD_STATUS}.result"
exit "${BUILD_STATUS}"
