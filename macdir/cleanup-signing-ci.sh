#!/bin/bash
set -euo pipefail
[[ "${GITHUB_ACTIONS:-}" == true && -n "${RUNNER_TEMP:-}" ]] || exit 1
rm -f "$RUNNER_TEMP/diakitw-103-signing.p12" "$RUNNER_TEMP/diakitw-103-notary.p8"
if [[ -f "$RUNNER_TEMP/diakitw-103-signing.keychain-db" ]]; then
  security delete-keychain "$RUNNER_TEMP/diakitw-103-signing.keychain-db"
fi
