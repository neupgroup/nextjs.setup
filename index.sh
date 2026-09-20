#!/usr/bin/env bash

set -Eeuo pipefail

: <<'NEUP_DOCUMENTATION'

:: Where to keep this file?
:: Clone the guidelines repository into /.neup/setup; this file is index.sh.

::neup.documentation::setup-script

Synchronizes the shared Neup repositories into the expected `.neup` folders.

Run `npm run setup` to update only repositories whose local HEAD is not the
latest commit on GitHub's `main` branch. Run `npm run setup -- force` (or
`npm run setup force`) to replace all four folders with fresh shallow clones.

::end
NEUP_DOCUMENTATION

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly NEUP_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

clone_repository() {
  local repository_url="$1"
  local target_directory="$2"

  rm -rf -- "$target_directory"
  git clone --depth 1 --single-branch --branch main "$repository_url" "$target_directory"
}

sync_repository() {
  local repository_url="$1"
  local target_directory="$2"
  local repository_name="$3"
  local remote_commit
  local local_commit

  remote_commit="$(git ls-remote "$repository_url" refs/heads/main | cut -f1)"
  if [[ -z "$remote_commit" ]]; then
    printf 'Unable to find the main branch for %s.\n' "$repository_url" >&2
    return 1
  fi

  if [[ -e "$target_directory/.git" ]]; then
    local_commit="$(git -C "$target_directory" rev-parse HEAD 2>/dev/null || true)"
    if [[ "$local_commit" == "$remote_commit" ]]; then
      printf '%s is already up to date (%s).\n' "$repository_name" "${local_commit:0:12}"
      return 0
    fi

    printf '%s is out of date; pulling the latest main commit.\n' "$repository_name"
    git -C "$target_directory" pull --ff-only origin main
    return 0
  elif [[ -e "$target_directory" ]]; then
    printf '%s is not a Git checkout; replacing it.\n' "$target_directory"
  else
    printf 'Cloning %s.\n' "$repository_name"
  fi

  clone_repository "$repository_url" "$target_directory"
}

mode="install"
force_sync=false
while (($#)); do
  case "$1" in
    --mode)
      mode="${2:?Missing value for --mode}"
      shift 2
      ;;
    --mode=*)
      mode="${1#*=}"
      shift
      ;;
    force)
      force_sync=true
      shift
      ;;
    *)
      shift
      ;;
  esac
done

case "$mode" in
  install|preinstall|postinstall|predev)
    mode="install"
    ;;
  optimize|prebuild|postbuild)
    mode="optimize"
    ;;
  install-clean|clean-install)
    force_sync=true
    ;;
  *)
    printf 'Unknown setup mode: %s\n' "$mode" >&2
    printf 'Expected install, optimize, install-clean, or clean-install.\n' >&2
    exit 2
    ;;
esac

mkdir -p -- "$NEUP_DIR"

repositories=(
  "https://github.com/neupgroup/neup.core|$NEUP_DIR/core|neup.core"
  "https://github.com/neupgroup/neup.logica|$NEUP_DIR/logica|neup.logica"
  "https://github.com/neupgroup/neup.react.components|$NEUP_DIR/components|neup.react.components"
)

if [[ "$mode" != "optimize" ]]; then
  repositories+=("https://github.com/neupgroup/devdomain.setup|$NEUP_DIR/domain|devdomain.setup")
fi

for repository in "${repositories[@]}"; do
  IFS='|' read -r repository_url target_directory repository_name <<< "$repository"

  if [[ "$force_sync" == true ]]; then
    printf 'Force syncing %s.\n' "$repository_name"
    clone_repository "$repository_url" "$target_directory"
  else
    sync_repository "$repository_url" "$target_directory" "$repository_name"
  fi
done

if [[ "$mode" == "optimize" ]]; then
  bash "$SCRIPT_DIR/generation/env.sh" "$NEUP_DIR/.."
  bash "$SCRIPT_DIR/modules.optimize.sh"
fi
