#!/bin/sh
set -e;

: "${TEST_COVERAGE_DIR_PATH:=coverageReport}";
: "${TEST_COVERAGE_FILE_NAME:=coverage.out}";

WATCH=0;
PROJ="";
FILTERS="";
USE_DOCKER=0;
RUNNING_IN_PIPELINE=0;
RUN_LOCAL_ENV=0;
TEST_TYPE="";
COVERAGE="";

while [ "$#" -gt 0 ]; do
  case "$1" in
    -w|--watch) WATCH=1; shift 1;;
    --docker) USE_DOCKER=1; shift 1;;
    --cicd) RUNNING_IN_PIPELINE=1; USE_DOCKER=1; shift 1;;
    --filter) FILTERS="--filter ${2}"; shift 2;;
    --unit) FILTERS="-tags=Unit"; TEST_TYPE="unit"; shift 1;;
    --integration) FILTERS="-tags=Integration"; TEST_TYPE="integration"; RUN_LOCAL_ENV=1; USE_DOCKER=1; shift 1;;
    --e2e) FILTERS="-tags=E2E"; TEST_TYPE="e2e"; RUN_LOCAL_ENV=1; USE_DOCKER=1; shift 1;;
    --coverage) COVERAGE="-covermode=atomic -coverprofile=${TEST_COVERAGE_DIR_PATH}/${TEST_COVERAGE_FILE_NAME} -coverpkg=./..."; FILTERS="-tags=Unit"; TEST_TYPE="unit"; shift 1;;

    -*) echo "unknown option: $1" >&2; exit 1;;
    *) PROJ=$1; shift 1;;
  esac
done

case "${TEST_TYPE}" in
  "unit")
    if ! find ./src -type f -path "./src/*/test/unit/*_test.go" -print -quit 2>/dev/null | grep -q .; then
      echo "No './src/*/test/unit/*_test.go' directory found. Assuming no unit tests exist.";
      exit 0;
    fi
    ;;
  "integration")
    if ! find ./src -type f -path "./src/*/test/integration/*_test.go" -print -quit 2>/dev/null | grep -q .; then
      echo "No './src/*/test/integration/*_test.go' directory found. Assuming no integration tests exist.";
      exit 0;
    fi
    ;;
  "e2e")
    if ! find ./src -type f -path "./src/*/test/e2e/*_test.go" -print -quit 2>/dev/null | grep -q .; then
      echo "No './src/*/test/e2e/*_test.go' directory found. Assuming no e2e tests exist.";
      exit 0;
    fi
    ;;
esac

if [ $RUN_LOCAL_ENV -eq 1 ]; then
  sh ./cli/start.sh -d;

  echo "Waiting for all Docker services to be healthy or up...";

  MAX_RETRIES=30;
  RETRY_DELAY=2;
  ATTEMPTS=0;

  COMPOSE_FILE="./setup/local/docker-compose.yml";
  PROJECT_NAME="myapp";

  while : ; do
    # List any containers that are not ready yet.
    # Rule: OK if .State == "running" and (no healthcheck OR Health == "healthy").
    # Ignore the one-shot db_init service.
    BAD_CONTAINERS=$(
      docker compose -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" ps --format '{{json .}}' \
      | jq -r '
          # ignore one-shot
          select((.Service // .Name) != "db_init")
          # not running OR (has healthcheck and not healthy)
          | select(
              (.State != "running")
              or
              ((.Health? // "") as $h | ($h != "" and $h != "healthy"))
            )
          | "\((.Service // .Name)): \(.State) (\(.Health // "no healthcheck"))"
        '
    );

    if [ -z "${BAD_CONTAINERS}" ]; then
      echo "All services are up and (if defined) healthy!";
      docker compose -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" ps;
      break;
    fi

    ATTEMPTS=$((ATTEMPTS+1));
    if [ ${ATTEMPTS} -ge ${MAX_RETRIES} ]; then
      echo "ERROR: Some services failed to become ready:";
      echo "${BAD_CONTAINERS}";
      echo "Recent logs (last 200 lines each):";
      docker compose -f "${COMPOSE_FILE}" -p "${PROJECT_NAME}" logs --tail=200;
      exit 1;
    fi

    sleep $RETRY_DELAY;
  done
else
  docker network create myapp_shared || true;
fi

if [ "${PROJ}" = "" ]; then
  for dir in ./src/*/ ; do
    PROJ="${PROJ} ${dir}...";
  done
fi

if [ -n "${COVERAGE}" ]; then
  rm -rf "./${TEST_COVERAGE_DIR_PATH}";
  mkdir -p "./${TEST_COVERAGE_DIR_PATH}";
fi

CMD="test -v ${FILTERS} ${COVERAGE} ${PROJ}";

if [ $WATCH -eq 1 ]; then
  if ! command -v gow >/dev/null 2>&1; then
    echo "gow not found. Installing...";
    go install github.com/mitranim/gow@latest;
  fi

  CMD="gow -c ${CMD}";
else
  CMD="go ${CMD}";
fi

if [ $USE_DOCKER -eq 1 ]; then
  INTERACTIVE_FLAGS="-it";
  if [ $RUNNING_IN_PIPELINE -eq 1 ]; then
    INTERACTIVE_FLAGS="-i";
  fi

  docker run --rm ${INTERACTIVE_FLAGS} --name myapp_test_runner --network=myapp_shared -v "./:/app/" -w "/app/" -e GOTOOLCHAIN=local golang:1.25 /bin/sh -c "${CMD}";
else
  eval "${CMD}";
fi
