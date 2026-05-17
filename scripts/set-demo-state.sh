#!/usr/bin/env bash
# set-demo-state.sh — flip the demo mocks for the Monday Snoonu demo
#
# These are webhook.site-backed mocks that the OpenCX AI calls. Changes are
# global and effective on the very next AI tool call (no deploy / no restart).
#
# Usage:
#   ./scripts/set-demo-state.sh <mode>
#
# Modes:
#   safe       count=2,  vertical=FOOD     # under threshold, F4 doesn't fire
#   over       count=6,  vertical=FOOD     # over threshold → block + supply slack
#   grocery    count=2,  vertical=GROCERY  # F4 bike→car redispatch
#   coffee     count=2,  vertical=COFFEE   # F4 coffee branch (>=50 QAR rule)
#   cake       count=2,  vertical=CAKE_ICE_CREAM
#   clean      count=0,  vertical=FOOD     # zero incident history
#   status                                  # show current values, don't change
#
# Set INCIDENTS=<n> as env var to override count: INCIDENTS=11 ./set-demo-state.sh over

set -eu

# Mock UUIDs (from /tmp/snoonu_mocks/*.uuid on the original setup machine).
# Stable as long as the tokens aren't deleted in webhook.site.
RC_UUID="ef640d3c-9487-4c6e-bb56-02b9194c2ce3"   # vehicle-issue removal count
TV_UUID="3e78f203-689a-4140-8b72-66565bba6c3a"   # task vertical
AGENT_ID="69fc6e0e006cade1b37697e7"
TASK_ID="6a0975c1c022ced0f45e9550"

mode="${1:-status}"
incidents="${INCIDENTS:-}"

set_rc() {
  local count="$1"
  curl -sS -X PUT "https://webhook.site/token/$RC_UUID" \
    -H "Content-Type: application/json" \
    -d "{\"default_content\":\"{\\\"agentId\\\":\\\"$AGENT_ID\\\",\\\"reason\\\":\\\"VEHICLE_ISSUE\\\",\\\"count\\\":$count}\",\"default_content_type\":\"application/json\",\"default_status\":200}" \
    > /dev/null
  echo "  removal_cases.count = $count"
}

set_tv() {
  local vertical="$1"
  curl -sS -X PUT "https://webhook.site/token/$TV_UUID" \
    -H "Content-Type: application/json" \
    -d "{\"default_content\":\"{\\\"taskId\\\":\\\"$TASK_ID\\\",\\\"vertical\\\":\\\"$vertical\\\"}\",\"default_content_type\":\"application/json\",\"default_status\":200}" \
    > /dev/null
  echo "  task_vertical = $vertical"
}

status() {
  echo "Current mock values:"
  echo "  removal_cases  → $(curl -sS "https://webhook.site/$RC_UUID/probe")"
  echo "  task_vertical  → $(curl -sS "https://webhook.site/$TV_UUID/probe")"
}

case "$mode" in
  safe)
    echo "Setting SAFE demo state (under-threshold, food order)…"
    set_rc "${incidents:-2}"
    set_tv FOOD
    ;;
  over)
    echo "Setting OVER-THRESHOLD demo state (block + supply slack path)…"
    set_rc "${incidents:-6}"
    set_tv FOOD
    ;;
  grocery)
    echo "Setting GROCERY demo state (F4 bike→car redispatch)…"
    set_rc "${incidents:-2}"
    set_tv GROCERY
    ;;
  coffee)
    echo "Setting COFFEE demo state (F4 coffee branch)…"
    set_rc "${incidents:-2}"
    set_tv COFFEE
    ;;
  cake)
    echo "Setting CAKE / ICE-CREAM demo state (F4 always-car branch)…"
    set_rc "${incidents:-2}"
    set_tv CAKE_ICE_CREAM
    ;;
  clean)
    echo "Setting CLEAN demo state (no incident history, food)…"
    set_rc "${incidents:-0}"
    set_tv FOOD
    ;;
  status)
    status
    ;;
  *)
    echo "unknown mode: $mode"
    echo "modes: safe | over | grocery | coffee | cake | clean | status"
    exit 1
    ;;
esac

echo
status
