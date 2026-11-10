#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

THREADS=${THREADS:-2}
CPUSETTINGS=${CPUSETTINGS:-'taskset -c 4,6'}
PROFILE_DIR="$ROOT/sim/verilator/profiles"
MAKEFILE="sim/verilator/Makefile.cvwsoc"

mkdir -p "$PROFILE_DIR"

usage() {
    echo "Usage: $0 <target>"
    echo
    echo "Targets:"
    echo "  cva6-rv32"
    echo "  cva6-rv64"
    echo "  wally-rv32"
    echo "  wally-rv64"
    echo "  cva6sp-rv32"
    echo "  cva6sp-rv64"
    echo "  vex-rv32"
    echo "  vexii-rv32"
    echo "  vexii-rv64"
    exit 1
}

[[ $# -eq 1 ]] || usage
TARGET="$1"
STAMP="$(date +%Y%m%d-%H%M%S)"

case "$TARGET" in
    cva6-rv32)
        FLAGS=(CVA6=1 RV32=1)
        ;;
    cva6-rv64)
        FLAGS=(CVA6=1 RV32=0)
        ;;
    wally-rv32)
        FLAGS=(RV32=1)
        ;;
    wally-rv64)
        FLAGS=(RV32=0)
        ;;
    cva6sp-rv32)
        FLAGS=(CVA6SP=1 RV32=1)
        ;;
    cva6sp-rv64)
        FLAGS=(CVA6SP=1 RV32=0)
        ;;
    vexii-rv64)
        FLAGS=(VEXII=1 RV32=0)
        ;;
    vexii-rv32)
        FLAGS=(VEXII=1 RV32=1)
        ;;
    vex-rv32)
        FLAGS=(VEX=1 RV32=1)
        ;;
    *)
        usage
        ;;
esac

PROFILE="${PROFILE_DIR}/profile-${TARGET}.vlt"
METADATA="${PROFILE}.meta"
# 12M cycles is probably enough (we don't want to spend too much time on this)
PROFILE_CYCLES=${PROFILE_CYCLES:-12000000}

TEMP_PROFILE="${PROFILE}.pending.$$"
TEMP_FOLDER="profile-temp"
trap 'rm -f "$TEMP_PROFILE"' EXIT

printf '\n%s\n' '=========================================================='
printf '\n%s\n' '=========================================================='
printf '\n%s\n' '=========================================================='
printf '\n%s\n' '=========================================================='
printf '  THREAD-PGO TRAINING: %s\n' "$TARGET"
printf '%s\n' "  Stage 1: train simulator for $PROFILE_CYCLES cycles."
printf '  Profile output: %s\n' "$PROFILE"
printf '%s\n\n' '=========================================================='
printf '%s\n\n' '=========================================================='
printf '%s\n\n' '=========================================================='
printf '%s\n\n' '=========================================================='
echo "Configuration: ${FLAGS[*]}"

PARAMS='--trace-depth $(TRACE_DEPTH) --threads $(THREADS) --prof-pgo'

# Generate profile
stdbuf -o0 -e0 make -f "$MAKEFILE" \
    CVA6=0 CVA6SP=0 VEX=0 \
    "${FLAGS[@]}" \
    run-cvwsoc-linux-fast \
    "WORKDIR=$ROOT/sim/verilator/$TEMP_FOLDER/thread-gen-${TARGET}-${STAMP}" \
    "CROSS_COMPILE=${CROSS_COMPILE:-riscv-none-elf-}" \
    -j6 \
    THREADS="$THREADS" \
    "PARAMS=$PARAMS" \
    "CPUSETTINGS=$CPUSETTINGS" \
    "UART_LOG=$ROOT/sim/verilator/$TEMP_FOLDER/thread-gen-${TARGET}-${STAMP}-uart.log" \
    "EXTRA_PLUS_ARGS=+MAX_CYCLES=$PROFILE_CYCLES +verilator+prof+vlt+file+$TEMP_PROFILE"

if [[ ! -s "$TEMP_PROFILE" ]]; then
    echo "ERROR: profile was not generated: $PROFILE" >&2
    exit 1
fi

mv "$TEMP_PROFILE" "$PROFILE"

{
    echo "threads=$THREADS"
    echo "affinity=$CPUSETTINGS"
    echo "dirty_state_begin"
    git status --short
    echo "dirty_state_end"
    echo "target=$TARGET"
    echo "flags=${FLAGS[*]}"
    echo "git_commit=$(git rev-parse HEAD 2>/dev/null || echo unknown)"
    echo "verilator=$(verilator --version 2>/dev/null || echo unknown)"
    echo "generated=$(date -Iseconds)"
    echo "profile_sha256=$(sha256sum "$PROFILE" | cut -d' ' -f1)"
    echo "tracked_diff_sha256=$(git diff | sha256sum | cut -d' ' -f1)"
} > "$METADATA"

printf '\n%s\n' '=========================================================='
printf '\n%s\n' '=========================================================='
printf '\n%s\n' '=========================================================='
printf '\n%s\n' '=========================================================='
printf '  THREAD-PGO TRAINING COMPLETE: %s\n' "$TARGET"
printf '  Profile saved: %s\n' "$PROFILE"
ls -lh "$PROFILE"
printf '%s\n' '=========================================================='
printf '%s\n' '=========================================================='
printf '%s\n' '=========================================================='
printf '%s\n' '=========================================================='

