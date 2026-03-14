#!/bin/zsh

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
private_remote="${1:-private}"
public_remote="${2:-public}"

git -C "$repo_root" remote get-url "$private_remote" >/dev/null
git -C "$repo_root" remote get-url "$public_remote" >/dev/null

git -C "$repo_root" push "$private_remote" main
git -C "$repo_root" push "$public_remote" public-main:main
