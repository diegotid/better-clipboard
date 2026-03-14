#!/bin/zsh

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
current_branch="$(git -C "$repo_root" rev-parse --abbrev-ref HEAD)"

if [[ "$current_branch" != "public-main" ]]; then
  echo "Expected to run on the public-main branch, found: $current_branch" >&2
  exit 1
fi

source_file="$repo_root/PublicMirror/Better/Services/PurchaseManager.swift"
target_file="$repo_root/Better/Services/PurchaseManager.swift"
clipboard_source_file="$repo_root/PublicMirror/Better/Services/ClipboardWatcher.swift"
clipboard_target_file="$repo_root/Better/Services/ClipboardWatcher.swift"

cp "$source_file" "$target_file"
cp "$clipboard_source_file" "$clipboard_target_file"

echo "Replaced Better/Services/PurchaseManager.swift with the public mirror version."
echo "Replaced Better/Services/ClipboardWatcher.swift with the public mirror version."
echo "Review the diff, then commit the public branch."
