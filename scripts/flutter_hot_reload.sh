#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "$0")/.." && pwd -P)"
pid_file="$project_root/.dart_tool/codex-flutter.pid"

if [[ ! -f "$pid_file" ]]; then
  echo 'Click Run first and wait for Flutter to finish starting.' >&2
  exit 1
fi

flutter_pid="$(cat "$pid_file")"
if [[ ! "$flutter_pid" =~ ^[1-9][0-9]*$ ]]; then
  echo 'Invalid Flutter PID. Click Run again.' >&2
  exit 1
fi

# Verify the process and project path before signaling a potentially reused PID.
flutter_command="$(ps -p "$flutter_pid" -o command= || true)"
if [[ "$flutter_command" != *flutter_tools.snapshot*" run "* || "$flutter_command" != *"--pid-file=$pid_file" ]]; then
  echo 'No Flutter process found for this project. Click Run again.' >&2
  exit 1
fi

kill -USR1 "$flutter_pid"
echo 'Hot reload requested. Check the Run terminal for the result.'
