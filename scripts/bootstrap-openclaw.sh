#!/usr/bin/env bash
set -euo pipefail

# openclaw-droplet-kit bootstrap
# Target: Ubuntu 22.04/24.04 on DigitalOcean

if [[ "${EUID}" -eq 0 ]]; then
  echo "Please run as a normal sudo user (not root)."
  echo "Tip: su - openclaw"
  exit 1
fi

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1"
    exit 1
  }
}

say() { echo -e "\n==> $*"; }

say "Installing base packages"
sudo apt-get update -y
sudo apt-get install -y curl git ca-certificates gnupg lsb-release

if ! command -v tailscale >/dev/null 2>&1; then
  say "Installing Tailscale"
  curl -fsSL https://tailscale.com/install.sh | sh
fi

if ! command -v openclaw >/dev/null 2>&1; then
  say "Installing OpenClaw (skip interactive onboarding)"
  curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard
  # shellcheck disable=SC1090
  [[ -f "$HOME/.bashrc" ]] && source "$HOME/.bashrc" || true
fi

require_cmd openclaw
require_cmd tailscale

say "Ensuring OpenClaw gateway baseline config"
openclaw config set gateway.bind loopback
openclaw config set gateway.auth.mode token
openclaw config set gateway.tailscale.mode serve
openclaw config set gateway.trustedProxies '["127.0.0.1"]'

say "Generating gateway token (if needed)"
openclaw doctor --generate-gateway-token || true

say "Starting/restarting gateway service"
openclaw gateway restart || openclaw gateway start

say "Checking service status"
openclaw gateway status || true

say "Tailscale setup"
if ! tailscale status >/dev/null 2>&1; then
  echo "Run this to complete Tailscale auth:"
  echo "  sudo tailscale up --ssh --hostname=openclaw"
else
  echo "Tailscale already authenticated."
fi

echo
echo "----------------------------------------"
echo "Bootstrap complete."
echo
echo "If Tailscale Serve is active, dashboard/chat is at:"
echo "  https://<your-tailnet-host>.ts.net/"
echo
echo "Fallback local access over SSH tunnel:"
echo "  ssh -L 18789:127.0.0.1:18789 <user>@<droplet>"
echo "  then open http://localhost:18789"
echo
echo "Gateway token is stored under ~/.openclaw (mode token)."
echo "----------------------------------------"
