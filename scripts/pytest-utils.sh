TIMESTAMP="$(date '+%Y%m%d%H%M%S')"

SCRIPTS_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
TRITON_TEST_REPORTS="${TRITON_TEST_REPORTS:-false}"
TRITON_TEST_REPORTS_DIR="${TRITON_TEST_REPORTS_DIR:-$HOME/reports/$TIMESTAMP}"
TRITON_TEST_SKIPLIST_DIR="${TRITON_TEST_SKIPLIST_DIR:-$SCRIPTS_DIR/skiplist/default}"
TRITON_TEST_WARNING_REPORTS="${TRITON_TEST_WARNING_REPORTS:-false}"
TRITON_TEST_IGNORE_ERRORS="${TRITON_TEST_IGNORE_ERRORS:-false}"

# absolute path for the selected skip list
TRITON_TEST_SKIPLIST_DIR="$(cd "$TRITON_TEST_SKIPLIST_DIR" && pwd)"
# absolute path for the current skip list
CURRENT_SKIPLIST_DIR="$SCRIPTS_DIR/skiplist/current"

pytest() {
    pytest_extra_args=()

    if [[ -v TRITON_TEST_SUITE && $TRITON_TEST_REPORTS = true ]]; then
        mkdir -p "$TRITON_TEST_REPORTS_DIR"
        pytest_extra_args+=(
            "--junitxml=$TRITON_TEST_REPORTS_DIR/$TRITON_TEST_SUITE.xml"
        )
    fi

    if [[ -v TRITON_TEST_SUITE && $TRITON_TEST_WARNING_REPORTS = true ]]; then
        mkdir -p "$TRITON_TEST_REPORTS_DIR"
        pytest_extra_args+=(
            "--warnings-output-file"
            "$TRITON_TEST_REPORTS_DIR/${TRITON_TEST_SUITE}-warnings.txt"
        )
    fi

    if [[ -v TRITON_TEST_SUITE && -f $TRITON_TEST_SKIPLIST_DIR/$TRITON_TEST_SUITE.txt ]]; then
        mkdir -p "$CURRENT_SKIPLIST_DIR"
        # skip comments in the skiplist
        sed -e '/^#/d' "$TRITON_TEST_SKIPLIST_DIR/$TRITON_TEST_SUITE.txt" > "$CURRENT_SKIPLIST_DIR/$TRITON_TEST_SUITE.txt"
        pytest_extra_args+=(
            "--deselect-from-file=$CURRENT_SKIPLIST_DIR/$TRITON_TEST_SUITE.txt"
            "--select-fail-on-missing"
        )
    fi

    python3 -u -m pytest "${pytest_extra_args[@]}" "$@" || $TRITON_TEST_IGNORE_ERRORS
}

capture_runtime_env() {
    mkdir -p "$TRITON_TEST_REPORTS_DIR"

    echo "$CMPLR_ROOT" > $TRITON_TEST_REPORTS_DIR/cmplr_version.txt
    echo "$MKLROOT" > $TRITON_TEST_REPORTS_DIR/mkl_version.txt

    # exit script execution as long as one of those components is not found.
    if [ -d "${SCRIPTS_DIR}/../python/dist" ]; then
        WHEEL=$(find ${SCRIPTS_DIR}/../python/dist -type f -name *.whl)
        if [[ ! -z "$WHEEL" ]]; then
            echo "$WHEEL" | sed -n 's/.*git\([a-zA-Z0-9]*\)[^a-zA-Z0-9].*/\1/p' > $TRITON_TEST_REPORTS_DIR/triton_commit_id.txt
            cp $TRITON_TEST_REPORTS_DIR/triton_commit_id.txt $TRITON_TEST_REPORTS_DIR/tests_commit_id.txt
        else
            echo "ERROR: Triton wheel is not found"
            exit 1
        fi
    else
        echo "ERROR: Triton wheel directory is not found"
        exit 1
    fi

    if which python &> /dev/null; then
        python --version | awk '{print $2}' > $TRITON_TEST_REPORTS_DIR/python_version.txt
    else
        echo "ERROR: python is not found"
        exit 1
    fi

    if python -c 'import triton' &> /dev/null; then
        python -c 'import triton; print(triton.__version__)' >  $TRITON_TEST_REPORTS_DIR/triton_version.txt
    else
        echo "ERROR: Triton is not found"
        exit 1
    fi

    if python -c 'import torch' &> /dev/null; then
        python -c 'import torch; print(torch.__version__)' > $TRITON_TEST_REPORTS_DIR/pytorch_version.txt
    else
        echo "ERROR: Torch is not found"
        exit 1
    fi

    if python -c 'import intel_extension_for_pytorch' &> /dev/null; then
        python -c 'import intel_extension_for_pytorch as ipex; print(ipex.__version__)' > $TRITON_TEST_REPORTS_DIR/IPEX_version.txt
    else
        echo "ERROR: IPEX is not found"
        exit 1
    fi
}
