#!/bin/bash
# =========================================================
#  sign-update.sh  -  run this AFTER any change to update.sh
#  Re-creates update.sh.sig so Infinity OS machines accept it.
#  Needs the "Infinity OS" private GPG key in your keyring.
# =========================================================
cd "$(dirname "$0")" || exit 1
sed -i 's/\r$//' update.sh    # force LF so the signature matches GitHub
gpg --batch --yes --local-user "Infinity OS" --detach-sign --armor -o update.sh.sig update.sh || { echo "SIGNING FAILED"; exit 1; }
if gpg --verify update.sh.sig update.sh 2>&1 | grep -q "Good signature"; then
  echo "Signed + verified OK."
  echo "Next: git add update.sh update.sh.sig version && git commit && git push"
else
  echo "VERIFY FAILED - do not push."
  exit 1
fi
