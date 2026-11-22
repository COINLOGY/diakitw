#!/usr/bin/env bash
set -euo pipefail
cd diakitw-android
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
curl -fLsS --max-time 60 https://repo.maven.apache.org/maven2/org/json/json/20240303/json-20240303.jar -o "$scratch/json.jar"
printf '%s  %s\n' 3cf6cd6892e32e2b4c1c39e0f52f5248a2f5b37646fdfbb79a66b46b618414ed "$scratch/json.jar" | sha256sum -c -
javac -cp "$scratch/json.jar" -d "$scratch/classes" app/src/main/java/app/diakitw/Updates.java tests/UpdatesTest.java tests/UpdatesTransportTest.java app/src/main/java/app/diakitw/Profiles.java tests/ProfilesTest.java
java -cp "$scratch/classes:$scratch/json.jar" app.diakitw.UpdatesTest
java -cp "$scratch/classes:$scratch/json.jar" app.diakitw.UpdatesTransportTest
java -cp "$scratch/classes:$scratch/json.jar" app.diakitw.ProfilesTest
