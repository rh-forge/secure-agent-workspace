#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
site_playbook="$repo_root/cloud-init/ansible/site.yml"
agent_playbook="$repo_root/cloud-init/ansible/agent.yml"

if grep -Fq 'python3-pip' "$site_playbook"; then
  echo "role dispatcher still requires python3-pip, which is unavailable on the saw-agent base image" >&2
  exit 1
fi

if ! python3 - "$agent_playbook" <<'PY'
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text()
repo_bootstrap = text.find("- name: Refresh and enable RHEL package repositories before package install")
refresh = text.find("- name: Refresh DNF metadata before package install")
availability = text.find("- name: Wait for required RHEL packages to become available")
install = text.find("- name: Ensure required packages are installed")
if repo_bootstrap == -1:
    print("agent playbook must refresh and enable RHEL repositories before package install", file=sys.stderr)
    sys.exit(1)
if refresh == -1:
    print("agent playbook must refresh DNF metadata before package install", file=sys.stderr)
    sys.exit(1)
if availability == -1:
    print("agent playbook must wait for required RHEL packages before package install", file=sys.stderr)
    sys.exit(1)
if install == -1:
    print("agent playbook package install task was not found", file=sys.stderr)
    sys.exit(1)
if repo_bootstrap > refresh:
    print("RHEL repository bootstrap must run before DNF metadata refresh", file=sys.stderr)
    sys.exit(1)
if refresh > availability:
    print("DNF metadata refresh must run before package availability check", file=sys.stderr)
    sys.exit(1)
if availability > install:
    print("RHEL package availability check must run before package install", file=sys.stderr)
    sys.exit(1)
required_window = text[availability:install]
for optional in ("telnet", "git", "lsof", "nodejs"):
    if optional in required_window:
        print(f"optional package {optional} must not gate required package availability", file=sys.stderr)
        sys.exit(1)
optional_install = text.find("- name: Install optional troubleshooting packages when available")
if optional_install == -1:
    print("agent playbook must install optional troubleshooting packages separately", file=sys.stderr)
    sys.exit(1)
if optional_install < install:
    print("optional troubleshooting packages must not install before required packages", file=sys.stderr)
    sys.exit(1)
PY
then
  exit 1
fi

echo "saw-agent package install is guarded for fresh VM DNF metadata"
