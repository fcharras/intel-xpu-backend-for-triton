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

PVC_DRIVER_SKIPLIST_DIR=""
source $SCRIPTS_DIR/capture-hw-details.sh -q
if [[ "$GPU_DRIVER_TYPE" == "rolling" && "$IS_PVC" == "true" ]]; then
    PVC_DRIVER_SKIPLIST_DIR="$SCRIPTS_DIR/skiplist/pvc_rolling"
fi

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

        # put skiplist/pvc_{rolling/lts}/language.txt to the current skiplist
        if [[ $TRITON_TEST_SUITE == "language" && ! -z $PVC_DRIVER_SKIPLIST_DIR ]]; then
            sed -e '/^#/d' "$PVC_DRIVER_SKIPLIST_DIR/$TRITON_TEST_SUITE.txt" >> "$CURRENT_SKIPLIST_DIR/$TRITON_TEST_SUITE.txt"
        fi

        pytest_extra_args+=(
            "--deselect-from-file=$CURRENT_SKIPLIST_DIR/$TRITON_TEST_SUITE.txt"
            "--select-fail-on-missing"
        )
    fi

    python3 -u -m pytest "${pytest_extra_args[@]}" "$@" || $TRITON_TEST_IGNORE_ERRORS
}
