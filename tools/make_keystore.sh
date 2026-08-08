#!/usr/bin/env bash
set -euo pipefail

# Creates a LOCAL Google Play upload key. Password and legal identity are entered
# interactively by keytool and are never stored in this repository or shell args.
KEYTOOL="${KEYTOOL:-keytool}"
OUT="${KEYSTORE_PATH:-keystore/arcane-trade-upload.keystore}"
ALIAS="${KEY_ALIAS:-arcane_trade_upload}"

command -v "$KEYTOOL" >/dev/null 2>&1 || {
  echo "keytool not found. Install a JDK or set KEYTOOL to its executable." >&2
  exit 1
}
if [[ -e "$OUT" ]]; then
  echo "Refusing to overwrite existing key: $OUT" >&2
  exit 1
fi

umask 077
mkdir -p "$(dirname "$OUT")"
"$KEYTOOL" -genkeypair -v \
  -keystore "$OUT" \
  -alias "$ALIAS" \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000

echo "Upload key created locally: $OUT"
echo "Alias: $ALIAS"
echo "Back up the key and password securely. Losing this key can block updates."
