#!/bin/bash

QUIET=false
for arg in "$@"; do
  case $arg in
    -q|--quiet)
      QUIET=true
      shift
      ;;
    --help)
      echo "Example usage: ./capture-hw-detauls.sh [-q | --quiet]"
      exit 1
      ;;
    *)
      ARGS+="${arg} "
      shift
      ;;
  esac
done

if dpkg-query --show libigc1 &> /dev/null; then
    export LIBIGC1_VERSION=$(dpkg-query --show --showformat='${version}\n' libigc1 | grep -oP '.+(?=~)')
else
    export LIBIGC1_VERSION="Not Installed"
fi

if dpkg-query --show intel-level-zero-gpu &> /dev/null; then
    export LEVEL_ZERO_VERSION=$(dpkg-query --show --showformat='${version}\n' intel-level-zero-gpu | grep -oP '.+(?=~)')
else
    export LEVEL_ZERO_VERSION="Not Installed"
fi

if dpkg-query --show libigc1 &> /dev/null; then
    export AGAMA_VERSION=$(dpkg-query --show --showformat='${version}\n' libigc1 | sed 's/.*-\(.*\)~.*/\1/')
else
    export AGAMA_VERSION="Not Installed"
fi

if command -v clinfo &> /dev/null; then
    export GPU_DEVICE=$(clinfo --json | jq -r '.devices[].online[].CL_DEVICE_NAME')
elif command -v nvidia-smi &> /dev/null; then
    export GPU_DEVICE=$(nvidia-smi -L | sed -e 's,\(.*\) (UUID.*),\1,')
else
    export GPU_DEVICE="Not Installed"
fi

if [ "$QUIET" = false ]; then
    echo "LIBIGC1_VERSION=$LIBIGC1_VERSION"
    echo "LEVEL_ZERO_VERSION=$LEVEL_ZERO_VERSION"
    echo "AGAMA_VERSION=$AGAMA_VERSION"
    echo "GPU_DEVICE=$GPU_DEVICE"
fi

agama_to_driver_type() {
    local lts=(803)
    local rolling=(821 775)

    local agama=$1
    local found="false"

    for item in "${lts[@]}"; do
        if [[ "$agama" -eq "$item" ]]; then
            echo "lts"
            found="true"
            break
        fi
    done

    if [[ "$found" == "false" ]]; then
        for item in "${rolling[@]}"; do
            if [[ "$agama" -eq "$item" ]]; then
                echo "rolling"
                found="true"
                break
            fi
        done
    fi

    if [ "$found" == "false" ]; then
        echo "Driver type is unknown"
    fi
}

xpu_is_pvc() {
    local lables=("GPU Max 1100" "GPU Max 1550")
    local xpu=$1
    local found="false"

    for device in "${lables[@]}"; do
        if echo "$xpu" | grep -q "$device"; then
            found="true"
            break
        fi
    done
    echo "$found"
}

GPU_DRIVER_TYPE=$(agama_to_driver_type "$AGAMA_VERSION")
IS_PVC=$(xpu_is_pvc "$GPU_DEVICE")
