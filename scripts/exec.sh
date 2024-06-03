#!/bin/bash -el

RES_FILE=$(pwd -P)/test_results.json

MATRIX_SIZES=(${MATRIX_SIZES-1024 2048})

declare -A NANOS6_CONFIG_EXEC_MODE
NANOS6_CONFIG_EXEC_MODE['d']="version.debug=true"
NANOS6_CONFIG_EXEC_MODE['p']=""

declare -A RUNTIME_MODE_EXEC_MODE
RUNTIME_MODE_EXEC_MODE['d']="debug"
RUNTIME_MODE_EXEC_MODE['p']="perf"

# Do not override NANOS6_CONFIG_OVERRIDE, as it might contain node-specific default values

for EXEC_MODE in d p; do
  for CREATE_FROM in 0 1; do
    for IDX in ${!MATRIX_SIZES[@]}; do
      MATRIX_SIZE=${MATRIX_SIZES[$IDX]}
      echo "=== Check mode: ${EXEC_MODE}, from: ${CREATE_FROM}, msize: ${MATRIX_SIZE} ==="
      #NOTE: Check == 0 -> Do not enable output result check (performance execution)
      #      Check == 1 -> Enable output result check
      CHECK=$([ "$IDX" == "0" ] && echo 1 || echo 0)
      NANOS6_CONFIG_OVERRIDE="$NANOS6_CONFIG_OVERRIDE,${NANOS6_CONFIG_EXEC_MODE[$EXEC_MODE]}" \
      RUNTIME_MODE=${RUNTIME_MODE_EXEC_MODE[$EXEC_MODE]} \
        ./build/matmul-${EXEC_MODE} ${MATRIX_SIZE} ${CHECK} ${CREATE_FROM}
      cat test_result.json >>$RES_FILE
      echo "," >>$RES_FILE
    done
  done
done
