#!/usr/bin/env bash

set -Eeuo pipefail

: <<'NEUP_DOCUMENTATION'
::neup.documentation::optimize-script

Prepares a Next.js application's `.neup` directory after setup. The canonical
development-domain checkout lives at `.neup/domain`; older locations are
removed when present.

Run this script from the application root with `./.neup/optimize.sh`.

::end
NEUP_DOCUMENTATION

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly NEUP_DIR="$SCRIPT_DIR"

# Remove paths created by older setup script versions. Keep the canonical
# `.neup/domain` repository and all other managed repositories intact.
for legacy_path in \
  "$NEUP_DIR/domain" \
  "$NEUP_DIR/core/domain" \
  "$NEUP_DIR/devDomain" \
  "$NEUP_DIR/devdomain.setup"; do
  if [[ -e "$legacy_path" ]]; then
    printf 'Removing obsolete path: %s\n' "$legacy_path"
    rm -rf -- "$legacy_path"
  fi
done

printf 'Neup preparation complete: %s\n' "$NEUP_DIR"
