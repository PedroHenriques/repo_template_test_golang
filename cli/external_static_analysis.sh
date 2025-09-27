#!/bin/sh
set -e;

: "${TEST_COVERAGE_DIR_PATH:=coverageReport}";
: "${TEST_COVERAGE_FILE_NAME:=coverage.out}";
: "${SONAR_QG_WAIT:=true}"
: "${SONAR_QG_TIMEOUT_SEC:=600}"

USE_DOCKER=0;
RUNNING_IN_PIPELINE=0;

while [ "$#" -gt 0 ]; do
  case "$1" in
    --docker) USE_DOCKER=1; shift 1;;
    --cicd) RUNNING_IN_PIPELINE=1; USE_DOCKER=1; shift 1;;

    -*) echo "unknown option: $1" >&2; exit 1;;
  esac
done

rm -rf .scannerwork;
mkdir -p .scannerwork;
chmod -R a+rwX .scannerwork;

if [ ! -f "${TEST_COVERAGE_DIR_PATH}/${TEST_COVERAGE_FILE_NAME}" ]; then
  echo "Coverage not found at ${TEST_COVERAGE_DIR_PATH}/${TEST_COVERAGE_FILE_NAME} — generating…";
  
  FLAGS="";
  if [ $RUNNING_IN_PIPELINE -eq 1 ]; then
    FLAGS="--cicd";
  elif [ $USE_DOCKER -eq 1 ]; then
    FLAGS="--docker";
  fi
  
  TEST_COVERAGE_DIR_PATH="${TEST_COVERAGE_DIR_PATH}" TEST_COVERAGE_FILE_NAME="${TEST_COVERAGE_FILE_NAME}" sh cli/coverage.sh ${FLAGS};
fi

EXTRA_OPTS="";
PR_KEY="";

if [ -n "${GITHUB_EVENT_PATH:-}" ] && [ -f "${GITHUB_EVENT_PATH}" ]; then
  PR_KEY="$(grep -o '"number":[[:space:]]*[0-9]\+' "$GITHUB_EVENT_PATH" | head -1 | grep -o '[0-9]\+' || true)";
fi

if [ -z "${PR_KEY}" ] && [ -n "${GITHUB_REF:-}" ]; then
  PR_KEY="$(printf '%s\n' "${GITHUB_REF}" | sed -n 's#refs/pull/\([0-9]\+\)/.*#\1#p')";
fi

if [ -n "${PR_KEY}" ]; then
  EXTRA_OPTS="$EXTRA_OPTS -Dsonar.pullrequest.key=${PR_KEY} -Dsonar.pullrequest.branch=${GITHUB_HEAD_REF} -Dsonar.pullrequest.base=${GITHUB_BASE_REF}";
else
  EXTRA_OPTS="$EXTRA_OPTS -Dsonar.branch.name=${GITHUB_REF_NAME}";
fi

CMD="sonar-scanner \
  -Dsonar.projectKey=${EXTERNAL_STATIC_ANALYSIS_PROJ_KEY} \
  -Dsonar.organization=${EXTERNAL_STATIC_ANALYSIS_ORG} \
  -Dsonar.host.url=${EXTERNAL_STATIC_ANALYSIS_HOST} \
  -Dsonar.sources=./src \
  -Dsonar.tests=./src \
  -Dsonar.test.inclusions=**/*_test.go \
  -Dsonar.exclusions=**/vendor/**,setup/**,app/setup/** \
  -Dsonar.coverage.exclusions=setup/**,app/setup/** \
  -Dsonar.go.coverage.reportPaths=${TEST_COVERAGE_DIR_PATH}/${TEST_COVERAGE_FILE_NAME} \
  ${EXTRA_OPTS} \
  -Dsonar.qualitygate.wait=${SONAR_QG_WAIT} \
  -Dsonar.qualitygate.timeout=${SONAR_QG_TIMEOUT_SEC}
";

if [ $USE_DOCKER -eq 1 ]; then
  INTERACTIVE_FLAGS="-it";
  if [ $RUNNING_IN_PIPELINE -eq 1 ]; then
    INTERACTIVE_FLAGS="-i";
  fi

  docker run --rm ${INTERACTIVE_FLAGS} -v "./:/usr/src" -w "/usr/src" -e SONAR_TOKEN="${EXTERNAL_STATIC_ANALYSIS_TOKEN}" -e GITHUB_EVENT_PATH -e GITHUB_REF -e GITHUB_HEAD_REF -e GITHUB_BASE_REF -e GITHUB_REF_NAME sonarsource/sonar-scanner-cli:latest /bin/sh -lc "${CMD}";
else
  eval "${CMD}";
fi
