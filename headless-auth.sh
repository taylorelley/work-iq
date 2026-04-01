#!/bin/sh
set -e

# headless-auth.sh — Authenticate WorkIQ without a local browser.
#
# Flow:
#   1. Starts `workiq ask` to trigger OAuth (listens on port 3334 internally)
#   2. Captures and displays the Microsoft login URL
#   3. User opens URL on any device with a browser, signs in
#   4. Browser redirects to localhost:3334 — this fails (no local server on that device)
#   5. User copies the full callback URL from the browser's address bar
#   6. Pastes it here
#   7. Script replays the URL inside the container against localhost:3334
#   8. Tokens are cached in ~/.mcp-auth/ for future use

# Fixed callback port — workiq always listens on 3334; this is not configurable.
CALLBACK_PORT=3334

# Build the tenant-id flag if configured
TENANT_FLAG=""
if [ -n "$WORKIQ_TENANT_ID" ] && [ "$WORKIQ_TENANT_ID" != "common" ]; then
  TENANT_FLAG="--tenant-id $WORKIQ_TENANT_ID"
fi

# Check if tokens already exist
if [ -d "$HOME/.mcp-auth" ] && [ "$(ls -A "$HOME/.mcp-auth" 2>/dev/null)" ]; then
  echo ""
  echo "Existing tokens found in ~/.mcp-auth/."
  echo "If authentication still fails, remove the directory contents and retry."
  echo ""
fi

echo "============================================"
echo "  WorkIQ Headless Authentication"
echo "============================================"
echo ""
echo "Starting WorkIQ to trigger authentication..."
echo ""

# Snapshot the current token state so we can detect new/updated files later
TOKEN_STATE_BEFORE=$(ls -lR "$HOME/.mcp-auth" 2>/dev/null || true)

# Create a temp file for capturing workiq output
AUTH_OUTPUT=$(mktemp)
AUTH_PID=""

cleanup() {
  if [ -n "$AUTH_PID" ] && kill -0 "$AUTH_PID" 2>/dev/null; then
    kill "$AUTH_PID" 2>/dev/null || true
    wait "$AUTH_PID" 2>/dev/null || true
  fi
  rm -f "$AUTH_OUTPUT"
}
trap cleanup EXIT INT TERM

# Start workiq ask in the background to trigger authentication.
# Redirect both stdout and stderr to capture the OAuth URL.
# shellcheck disable=SC2086
workiq $TENANT_FLAG ask -q "test" >"$AUTH_OUTPUT" 2>&1 &
AUTH_PID=$!

# Wait for the OAuth URL to appear in the output (up to 30 seconds)
TIMEOUT=30
ELAPSED=0
AUTH_URL=""

while [ $ELAPSED -lt $TIMEOUT ]; do
  if [ -f "$AUTH_OUTPUT" ]; then
    # Look for a Microsoft login URL in the output
    AUTH_URL=$(grep -oE 'https://login\.microsoftonline\.com/[^ ]+' "$AUTH_OUTPUT" 2>/dev/null | head -1) || true
    if [ -n "$AUTH_URL" ]; then
      break
    fi
    # Also check for any generic auth URL pattern
    AUTH_URL=$(grep -oE 'https://[^ ]*oauth[^ ]*|https://[^ ]*authorize[^ ]*|https://[^ ]*login[^ ]*' "$AUTH_OUTPUT" 2>/dev/null | head -1) || true
    if [ -n "$AUTH_URL" ]; then
      break
    fi
  fi
  sleep 1
  ELAPSED=$((ELAPSED + 1))

  # Check if workiq exited early (might already be authenticated)
  if ! kill -0 "$AUTH_PID" 2>/dev/null; then
    # Process exited — check if it succeeded (already authenticated)
    if wait "$AUTH_PID" 2>/dev/null; then
      echo "Authentication already complete — tokens are cached."
      echo ""
      echo "Output:"
      cat "$AUTH_OUTPUT"
      exit 0
    fi
    break
  fi
done

if [ -z "$AUTH_URL" ]; then
  echo "Could not detect an authentication URL."
  echo ""
  echo "WorkIQ output:"
  cat "$AUTH_OUTPUT"
  echo ""
  echo "If WorkIQ did not request authentication, tokens may already be cached."
  echo "Otherwise, check the output above for a sign-in URL and use it manually."
  exit 1
fi

echo "--------------------------------------------"
echo "  Open this URL on any device with a browser:"
echo ""
echo "  $AUTH_URL"
echo ""
echo "--------------------------------------------"
echo ""
echo "After signing in, your browser will try to redirect to"
echo "  http://localhost:${CALLBACK_PORT}/..."
echo "and show an error or blank page. This is expected."
echo ""
echo "Copy the FULL URL from your browser's address bar and"
echo "paste it below."
echo ""
printf "Callback URL: "
read -r CALLBACK_URL

if [ -z "$CALLBACK_URL" ]; then
  echo "No URL provided. Aborting."
  exit 1
fi

# Validate the URL looks like a callback
case "$CALLBACK_URL" in
  http://localhost:${CALLBACK_PORT}/*|http://127.0.0.1:${CALLBACK_PORT}/*)
    ;;
  *)
    echo ""
    echo "Warning: URL does not start with http://localhost:${CALLBACK_PORT}/"
    echo "Attempting to use it anyway..."
    echo ""
    ;;
esac

echo ""
echo "Delivering callback to WorkIQ..."

# Replay the callback URL against the local server inside the container.
# Use Node.js (already available) instead of requiring curl.
node -e "
  const http = require('http');
  const url = new URL(process.argv[1]);
  const options = {
    hostname: '127.0.0.1',
    port: ${CALLBACK_PORT},
    path: url.pathname + url.search,
    method: 'GET',
    timeout: 10000
  };
  const req = http.request(options, (res) => {
    let body = '';
    res.on('data', (chunk) => body += chunk);
    res.on('end', () => {
      if (res.statusCode >= 200 && res.statusCode < 400) {
        console.log('Callback delivered successfully.');
      } else {
        console.error('Callback returned status ' + res.statusCode);
        if (body) console.error(body);
        process.exit(1);
      }
    });
  });
  req.on('error', (err) => {
    console.error('Failed to deliver callback: ' + err.message);
    process.exit(1);
  });
  req.on('timeout', () => {
    req.destroy();
    console.error('Callback request timed out.');
    process.exit(1);
  });
  req.end();
" "$CALLBACK_URL"

# Wait for the background workiq process to finish the token exchange.
# Use a timeout so we don't hang indefinitely.
echo ""
echo "Waiting for token exchange to complete..."

AUTH_TIMEOUT=30
AUTH_ELAPSED=0
AUTH_EXIT=0

while [ $AUTH_ELAPSED -lt $AUTH_TIMEOUT ]; do
  if ! kill -0 "$AUTH_PID" 2>/dev/null; then
    # Process exited — capture its exit status
    wait "$AUTH_PID" 2>/dev/null && AUTH_EXIT=0 || AUTH_EXIT=$?
    break
  fi
  sleep 1
  AUTH_ELAPSED=$((AUTH_ELAPSED + 1))
done

# If the process is still running after the timeout, terminate it
if kill -0 "$AUTH_PID" 2>/dev/null; then
  echo "WorkIQ did not exit within ${AUTH_TIMEOUT}s — terminating."
  kill "$AUTH_PID" 2>/dev/null || true
  wait "$AUTH_PID" 2>/dev/null || true
  AUTH_EXIT=1
fi

# Clear PID so the cleanup trap doesn't try to kill an already-waited process
AUTH_PID=""

# Determine success by checking the process exit status and whether
# new or updated token files appeared since the script started.
if [ "$AUTH_EXIT" -ne 0 ]; then
  echo ""
  echo "Authentication failed (exit status $AUTH_EXIT)."
  echo ""
  echo "WorkIQ output:"
  cat "$AUTH_OUTPUT"
  exit 1
fi

# Compare token state to the pre-auth snapshot
TOKEN_STATE_AFTER=$(ls -lR "$HOME/.mcp-auth" 2>/dev/null || true)
if [ "$TOKEN_STATE_AFTER" != "$TOKEN_STATE_BEFORE" ]; then
  echo ""
  echo "============================================"
  echo "  Authentication successful!"
  echo "============================================"
  echo ""
  echo "Tokens have been cached in ~/.mcp-auth/"
  echo ""
  echo "You can now run WorkIQ without a browser:"
  echo "  docker run -i --rm -v ~/.mcp-auth:/home/workiq/.mcp-auth workiq-mcp"
  echo ""
else
  echo ""
  echo "Warning: No new tokens found in ~/.mcp-auth/ after authentication."
  echo "The token files were unchanged. Authentication may have failed or"
  echo "the existing cached tokens were already valid."
  echo ""
  echo "WorkIQ output:"
  cat "$AUTH_OUTPUT"
  exit 1
fi
