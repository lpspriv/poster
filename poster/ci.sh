#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${REGISTRY_PASSWORD:-}" ]]; then
  printf 'REGISTRY_PASSWORD must be set in the environment.\n' >&2
  exit 1
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(git -C "$script_dir/.." rev-parse --show-toplevel)"
build_context="$repo_root/poster"
image_name="registry.lpspriv.com:5000/poster-api"
commit_sha="$(git -C "$repo_root" rev-parse HEAD)"

dirty_context="$(
  git -C "$repo_root" status --porcelain --untracked-files=all -- poster |
    awk '$NF != "poster/ci.sh"'
)"
if [[ -n "$dirty_context" ]]; then
  printf 'Commit all Poster image source changes before publishing:\n%s\n' "$dirty_context" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1 || ! docker buildx version >/dev/null 2>&1; then
  printf 'Docker with Buildx is required to build and publish the Poster image.\n' >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  printf 'Docker is not running or the current user cannot access it.\n' >&2
  exit 1
fi

if ! printf '%s' "$REGISTRY_PASSWORD" |
  docker login registry.lpspriv.com:5000 \
    --username lps-publisher \
    --password-stdin; then
  printf 'Registry login failed. Check the lps-publisher credentials.\n' >&2
  exit 1
fi

image_reference="${image_name}:${commit_sha}"
printf 'Building and pushing %s for linux/amd64...\n' "$image_reference"
docker buildx build \
  --platform linux/amd64 \
  --tag "$image_reference" \
  --push \
  "$build_context"

printf 'Published %s\n' "$image_reference"
printf 'Set image.repository=registry.lpspriv.com:5000 and image.tag=%s in the Poster HelmRelease values to deploy it.\n' "$commit_sha"
