#!/bin/bash
set -e

# Usage helper
show_usage() {
    echo "Usage: $0 <17|18> <unoptimized|optimized> [duration_seconds]"
    echo "Example: $0 17 unoptimized 15"
    exit 1
}

# Parameters
VERSION=${1}
WORKLOAD=${2}
DURATION=${3:-20}

if [ -z "$VERSION" ] || [ -z "$WORKLOAD" ]; then
    show_usage
fi

if [ "$VERSION" != "17" ] && [ "$VERSION" != "18" ]; then
    echo "Error: Version must be 17 or 18."
    show_usage
fi

if [ "$WORKLOAD" != "unoptimized" ] && [ "$WORKLOAD" != "optimized" ]; then
    echo "Error: Workload must be 'unoptimized' or 'optimized'."
    show_usage
fi

CONTAINER="tuning_lab_pg${VERSION}"
WORKLOAD_FILE="workloads/${WORKLOAD}_workload.sql"

# Check if workload file exists
if [ ! -f "$WORKLOAD_FILE" ]; then
    echo "Error: Workload file $WORKLOAD_FILE does not exist."
    exit 1
fi

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo "Error: Container ${CONTAINER} is not running."
    echo "Please start the lab using: docker compose up -d"
    exit 1
fi

echo "======================================================================"
echo " Starting PGbench Workload Test"
echo " PostgreSQL Version : ${VERSION}"
echo " Workload Type     : ${WORKLOAD}"
echo " Duration (sec)    : ${DURATION}"
echo " Clients / Threads : 4 / 2"
echo "======================================================================"

# Run pgbench inside container by piping the SQL workload through stdin
docker exec -i "${CONTAINER}" pgbench \
  -n \
  -U postgres \
  -c 4 \
  -j 2 \
  -T "${DURATION}" \
  -f - \
  tuning_lab < "${WORKLOAD_FILE}"

echo "======================================================================"
echo " Benchmark Complete!"
echo "======================================================================"
