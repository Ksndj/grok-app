#!/usr/bin/env bash
# *** Fork-local / 不贡献 ***
# This script exists only on the Ksndj/grok-app fork.
# Do NOT propose, copy, or include it in PRs to upstream RongleCat/grok-app.
# 本脚本仅本 fork 使用；勿向上游 RongleCat/grok-app 提 PR 或包含此文件。
#
# Create or refresh the rolling GitHub prerelease `nightly` for main-branch
# installers. Does not become GitHub "latest" (official v* releases stay latest).
#
# Env:
#   GH_TOKEN / GITHUB_TOKEN   required
#   GITHUB_SHA                commit to attach (Actions default)
#   GITHUB_REPOSITORY         owner/repo
#   GITHUB_SERVER_URL         optional (https://github.com)
#   NIGHTLY_NOTES_ONLY=1      update title/notes/flags only (do not delete assets)
#   NIGHTLY_TAG               default nightly
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

TAG="${NIGHTLY_TAG:-nightly}"
SHA="${GITHUB_SHA:-$(git rev-parse HEAD)}"
SHORT="$(git rev-parse --short "$SHA")"
REPO="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
SERVER="${GITHUB_SERVER_URL:-https://github.com}"
VER="$(python3 -c 'import json; print(json.load(open("package.json"))["version"])')"
DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

export GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN:-}}"
if [[ -z "${GH_TOKEN}" ]]; then
  echo "error: GH_TOKEN or GITHUB_TOKEN is required" >&2
  exit 1
fi

NOTES="$(mktemp)"
trap 'rm -f "$NOTES"' EXIT

{
  echo "# Grok App nightly"
  echo
  echo "Built from \`main\` at [\`${SHORT}\`](${SERVER}/${REPO}/commit/${SHA}) (${DATE})."
  echo "App version inside the packages: **${VER}** (this is not a tagged stable release)."
  echo
  echo "This rolling **prerelease** is overwritten on each \`main\` push that changes the app."
  echo "GitHub **latest** stays on official \`v*\` releases — do not use this tag for grok-app.com."
  echo
  echo "Code signing: Windows Authenticode and Apple notarization run when the corresponding Actions secrets are set. Missing secrets still produce installers (unsigned)."
  echo
  echo "## Recent commits"
  git log -15 --pretty=format:'- %h %s' "$SHA"
  echo
} > "$NOTES"

# Point the rolling tag at this commit so the Release "source" matches the bits.
if git rev-parse -q --verify "refs/tags/${TAG}" >/dev/null; then
  git tag -f "$TAG" "$SHA"
else
  git tag "$TAG" "$SHA"
fi
if ! git push origin "refs/tags/${TAG}" --force; then
  echo "warn: could not push tag ${TAG}; release assets will still upload" >&2
fi

TITLE="Grok App nightly (${SHORT})"
NOTES_ONLY="${NIGHTLY_NOTES_ONLY:-0}"
if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  if [[ "$NOTES_ONLY" != "1" ]]; then
    while IFS= read -r name; do
      [[ -z "${name:-}" ]] && continue
      gh release delete-asset "$TAG" "$name" --repo "$REPO" --yes
    done < <(gh release view "$TAG" --repo "$REPO" --json assets --jq '.assets[].name' 2>/dev/null || true)
  fi
  gh release edit "$TAG" \
    --repo "$REPO" \
    --title "$TITLE" \
    --notes-file "$NOTES" \
    --prerelease \
    --latest=false \
    --target "$SHA"
  echo "updated existing ${TAG} prerelease"
else
  gh release create "$TAG" \
    --repo "$REPO" \
    --title "$TITLE" \
    --notes-file "$NOTES" \
    --prerelease \
    --latest=false \
    --target "$SHA"
  echo "created ${TAG} prerelease"
fi

echo "NIGHTLY_TAG=${TAG}"
echo "NIGHTLY_SHA=${SHA}"
echo "NIGHTLY_VERSION=${VER}"
