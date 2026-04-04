#!/bin/bash
set -euo pipefail

# Only run in Claude Code remote/web environment
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-/home/user/elevenlabs-webrtc}"
ENV_FILE="${CLAUDE_ENV_FILE:-/dev/null}"

echo "=== MedSimAI Session Start Hook ==="

# ---------- 1. System dependencies ----------
echo "Installing system dependencies..."
apt-get update -qq
apt-get install -y -qq elixir erlang-dev erlang-xmerl erlang-parsetools libsrtp2-dev socat >/dev/null 2>&1
echo "System deps installed."

# ---------- 2. Elixir 1.17 (ex_webrtc needs >= 1.15) ----------
ELIXIR_DIR="/usr/local/elixir-1.17"
if [ ! -f "$ELIXIR_DIR/bin/elixir" ]; then
  echo "Installing Elixir 1.17..."
  curl -sL "https://github.com/elixir-lang/elixir/releases/download/v1.17.3/elixir-otp-25.zip" -o /tmp/elixir.zip
  unzip -qo /tmp/elixir.zip -d "$ELIXIR_DIR"
  rm -f /tmp/elixir.zip
  echo "Elixir 1.17 installed."
else
  echo "Elixir 1.17 already installed."
fi

# Persist PATH and Elixir options for the session
echo "export PATH=\"$ELIXIR_DIR/bin:\$PATH\"" >> "$ENV_FILE"
echo 'export ELIXIR_ERL_OPTIONS="+fnu"' >> "$ENV_FILE"

# Apply for current script execution too
export PATH="$ELIXIR_DIR/bin:$PATH"
export ELIXIR_ERL_OPTIONS="+fnu"

echo "Elixir version: $(elixir --version 2>&1 | grep Elixir)"

# ---------- 3. Hex package manager ----------
echo "Installing Hex..."
mix archive.install github hexpm/hex branch latest --force >/dev/null 2>&1
echo "Hex installed."

# Configure Hex to trust the system CA bundle (includes Anthropic proxy TLS Inspection CA)
mix hex.config cacerts_path /etc/ssl/certs/ca-certificates.crt >/dev/null 2>&1
echo "Hex cacerts_path set to system CA bundle."

# ---------- 4. Rebar3 (for Erlang deps like telemetry) ----------
ELIXIR_MINOR=$(elixir -e 'IO.puts(System.version() |> String.split(".") |> Enum.take(2) |> Enum.join("-"))')
REBAR_DIR="/root/.mix/elixir/$ELIXIR_MINOR"
mkdir -p "$REBAR_DIR"

if [ ! -f "$REBAR_DIR/rebar3" ] || [ $(stat -c%s "$REBAR_DIR/rebar3") -lt 1000 ]; then
  echo "Installing rebar3..."
  curl -sL "https://github.com/erlang/rebar3/releases/download/3.24.0/rebar3" -o "$REBAR_DIR/rebar3"
  chmod +x "$REBAR_DIR/rebar3"
  cp "$REBAR_DIR/rebar3" /root/.mix/rebar3
  echo "rebar3 installed."
else
  echo "rebar3 already installed."
fi

# ---------- 5. Local Hex HTTP proxy ----------
# Erlang's httpc can't do TLS through the Anthropic HTTPS proxy properly.
# This tiny Python HTTP server bridges requests to repo.hex.pm via urllib
# (which uses system TLS and handles the proxy correctly).
HEX_PROXY_PORT=8888
HEX_PROXY_SCRIPT="$PROJECT_DIR/.claude/hooks/hex_proxy.py"

# Check if proxy is already running
if curl -s --max-time 2 "http://127.0.0.1:$HEX_PROXY_PORT/names" >/dev/null 2>&1; then
  echo "Hex HTTP proxy already running on port $HEX_PROXY_PORT."
else
  echo "Starting Hex HTTP proxy on port $HEX_PROXY_PORT..."
  nohup python3 "$HEX_PROXY_SCRIPT" >/dev/null 2>&1 &
  # Wait for proxy to be ready
  for i in $(seq 1 10); do
    if curl -s --max-time 2 "http://127.0.0.1:$HEX_PROXY_PORT/names" >/dev/null 2>&1; then
      echo "Hex HTTP proxy ready."
      break
    fi
    sleep 0.5
  done
fi

echo "export HEX_MIRROR_URL=\"http://127.0.0.1:$HEX_PROXY_PORT\"" >> "$ENV_FILE"
export HEX_MIRROR_URL="http://127.0.0.1:$HEX_PROXY_PORT"

# ---------- 6. Elixir dependencies ----------
cd "$PROJECT_DIR"

echo "Fetching Elixir dependencies..."
mix deps.get >/dev/null 2>&1
echo "Dependencies fetched."

echo "Compiling project..."
mix compile >/dev/null 2>&1
echo "Project compiled."

echo "=== Session Start Hook Complete ==="
