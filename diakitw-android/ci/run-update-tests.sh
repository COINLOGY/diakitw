#!/usr/bin/env bash
set -euo pipefail
cd diakitw-android
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
curl -fLsS --max-time 60 https://repo.maven.apache.org/maven2/org/json/json/20240303/json-20240303.jar -o "$scratch/json.jar"
javac -cp "$scratch/json.jar" -d "$scratch/classes" app/src/main/java/app/diakitw/Updates.java tests/UpdatesTest.java tests/UpdatesTransportTest.java
java -cp "$scratch/classes:$scratch/json.jar" app.diakitw.UpdatesTest
java -cp "$scratch/classes:$scratch/json.jar" app.diakitw.UpdatesTransportTest
