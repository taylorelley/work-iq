#!/bin/sh
set -e

# Prepend --tenant-id if configured, then default to "mcp" subcommand
if [ -n "$WORKIQ_TENANT_ID" ] && [ "$WORKIQ_TENANT_ID" != "common" ]; then
  if [ $# -eq 0 ]; then
    exec workiq --tenant-id "$WORKIQ_TENANT_ID" mcp
  else
    exec workiq --tenant-id "$WORKIQ_TENANT_ID" "$@"
  fi
else
  if [ $# -eq 0 ]; then
    exec workiq mcp
  else
    exec workiq "$@"
  fi
fi
