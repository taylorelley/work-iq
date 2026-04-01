#!/bin/sh
set -e

# Build the command arguments
ARGS=""

# Translate WORKIQ_TENANT_ID env var to --tenant-id flag
if [ -n "$WORKIQ_TENANT_ID" ] && [ "$WORKIQ_TENANT_ID" != "common" ]; then
  ARGS="--tenant-id $WORKIQ_TENANT_ID"
fi

# Default command is "mcp"; allow override via extra args
if [ $# -eq 0 ]; then
  exec workiq $ARGS mcp
else
  exec workiq $ARGS "$@"
fi
