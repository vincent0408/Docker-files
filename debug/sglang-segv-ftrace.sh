#!/usr/bin/env bash
# Trace who generates SIGSEGV for the sglang scheduler using the kernel's
# built-in ftrace (no packages needed). Run on the HOST as root.
#
#   sudo ./debug/sglang-segv-ftrace.sh start   # begin logging
#   sudo ./debug/sglang-segv-ftrace.sh show    # print the scheduler's SIGSEGV events
#   sudo ./debug/sglang-segv-ftrace.sh stop    # turn tracing off again
#
# How to read "show":
#   code=1 or 2, stack contains exc_page_fault   -> real CPU page fault (hardware side)
#   code=0 or -6, stack contains kill/tgkill     -> signal was SENT; the task at the
#                                                   start of the line is the sender
#   A second code=-6 event from the scheduler itself is the faulthandler re-raise.
set -euo pipefail

LOG=${LOG:-/var/tmp/sglang-segv-ftrace.log}
PIDFILE=/var/tmp/sglang-segv-ftrace.pid
EV=events/signal/signal_generate

[[ $EUID -eq 0 ]] || { echo "run as root (sudo)" >&2; exit 1; }

if [[ -d /sys/kernel/tracing/events ]]; then
    T=/sys/kernel/tracing
elif [[ -d /sys/kernel/debug/tracing/events ]]; then
    T=/sys/kernel/debug/tracing
else
    mount -t tracefs nodev /sys/kernel/tracing
    T=/sys/kernel/tracing
fi

start() {
    if [[ -f $PIDFILE ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        echo "already running (pid $(cat "$PIDFILE")), log: $LOG"; return
    fi
    echo 'sig == 11' > "$T/$EV/filter"
    echo 'stacktrace if sig == 11' > "$T/$EV/trigger"
    echo 1 > "$T/$EV/enable"
    echo 1 > "$T/tracing_on"
    nohup cat "$T/trace_pipe" >> "$LOG" 2>&1 &
    echo $! > "$PIDFILE"
    echo "tracing SIGSEGV generation -> $LOG (reader pid $!)"
}

stop() {
    echo 0 > "$T/$EV/enable"
    echo '!stacktrace if sig == 11' > "$T/$EV/trigger" 2>/dev/null || true
    echo 0 > "$T/$EV/filter"
    if [[ -f $PIDFILE ]]; then
        kill "$(cat "$PIDFILE")" 2>/dev/null || true
        rm -f "$PIDFILE"
    fi
    echo "tracing stopped; log kept at $LOG"
}

show() {
    [[ -f $LOG ]] || { echo "no log at $LOG"; exit 1; }
    grep -A25 "comm=sglang::schedul" "$LOG" || echo "no SIGSEGV for sglang::schedul recorded yet"
}

case "${1:-}" in
    start) start ;;
    stop)  stop ;;
    show)  show ;;
    *) echo "usage: $0 {start|stop|show}" >&2; exit 2 ;;
esac
