#!/bin/sh
# Fake SSH: exercise askpass pipe without network/Keychain.
[ "$SSH_ASKPASS_REQUIRE" = force ] || exit 2
[ -z "$SECRET_MUST_NOT_PASS" ] || exit 3
password="$("$SSH_ASKPASS" "user@example.invalid's password: ")" || exit 4
[ "$password" = synthetic-test-only ] || exit 5
unset password
/bin/cat
