#!/bin/bash
readonly BUILD_SCRIPT=${BUILD_SCRIPT:-'1'}
readonly ENV_FILE=$1
shift

# shellcheck source=library.sh
source "${HERA_HOME}"/library.sh

dumpBuildEnv() {
  local env_dump_file

  env_dump_file=${1}

  is_defined "${env_dump_file}" "No filename provided to store env."

  env | grep -e 'WORKSPACE' -e 'JAVA_HOME' -e 'MAVEN_' | sed -e 's;^;export ;;' > "${env_dump_file}"
  chmod +x "${env_dump_file}"
  if [ "${PIPESTATUS[0]}" -ne "0" ]; then
    echo "Env command failed"
    exit 1
  fi
}

is_defined "${BUILD_SCRIPT}" 'No build script provided' 2

readonly CONTAINER_NAME=$(container_name "${JOB_NAME}" "${BUILD_ID}")

dumpBuildEnv "${HERA_HOME}/build-env.sh"

# format in the env file is line delimited xx=yy
env_file_if_enabled() {
  if [ -n "${ENV_FILE}" ]; then
    env_lines=""
    while IFS= read -r line
    do
      env_lines+=" -e $line"
    done < <(grep -v '^ *#' < "${ENV_FILE}")
    echo "${env_lines}"
  fi
}

set +u
run_ssh "podman exec $(env_file_if_enabled) \
        -e LANG='en_US.utf8' \
        -e JOB_NAME="${JOB_NAME}" \
        -e PARENT_JOB_NAME="${PARENT_JOB_NAME}" \
        -e PARENT_JOB_BUILD_ID="${PARENT_JOB_BUILD_ID}" \
        -e PARENT_CORE_JOB_NAME="${PARENT_CORE_JOB_NAME}" \
        -e PARENT_CORE_JOB_BUILD_ID="${PARENT_CORE_JOB_BUILD_ID}" \
        -e WORKSPACE="${WORKSPACE}" \
        -e WORKDIR="${WORKDIR}" \
        -e HARMONIA_SCRIPT="${HARMONIA_SCRIPT}" \
        -e DEBUG="${DEBUG}" \
        -e BUILD_ID="${BUILD_ID}" \
        -e BUILD_COMMAND="${BUILD_COMMAND}" \
        -e COPY_ARTIFACTS="${COPY_ARTIFACTS}" \
        -e RERUN_FAILING_TESTS="${RERUN_FAILING_TESTS}" \
        -ti ${CONTAINER_NAME} '${BUILD_SCRIPT}' ${@}" | removeColorsControlCharactersFromOutput
exit "${PIPESTATUS[0]}"
