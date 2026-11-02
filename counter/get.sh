#!/usr/bin/env bash
# Part Counter installer / updater.
# Run on the Raspberry Pi (the exact line is shown on the Part Counter page):
#   curl -fsSL <site>/partcounter/get.sh | bash -s -- <site>/partcounter/
set -e
BASE="${1:-}"
if [ -z "$BASE" ]; then
  echo "Copy the full command from the Part Counter web page, it includes the download address."
  exit 1
fi
BASE="${BASE%/}/"
DIR="$HOME/partcounter"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "== Downloading Part Counter from ${BASE} =="
curl -fsSL -H "Cache-Control: no-cache" "${BASE}partcounter.zip?$(date +%s)" -o "$TMP/pc.zip"
python3 -m zipfile -e "$TMP/pc.zip" "$TMP/x"
[ -f "$TMP/x/partcounter/app.py" ] || { echo "Download looks wrong, nothing changed."; exit 1; }

mkdir -p "$DIR/data"
cp -r "$TMP/x/partcounter/." "$DIR/"          # data/ (parts, settings, log) is never in the zip
chmod +x "$DIR/install.sh" "$DIR/app.py"
echo "$BASE" > "$DIR/data/update_url.txt"      # lets the Update button in the app find new versions

if [ -f /etc/systemd/system/partcounter.service ]; then
echo "== Allowing the counter's Shut down / Restart buttons =="
RULE_USER="${SUDO_USER:-$USER}"
TMPR="$(mktemp)"
echo "$RULE_USER ALL=(root) NOPASSWD: /usr/bin/systemctl poweroff, /usr/bin/systemctl reboot" > "$TMPR"
if sudo visudo -cf "$TMPR" >/dev/null; then
  sudo install -m 0440 -o root -g root "$TMPR" /etc/sudoers.d/partcounter
fi
rm -f "$TMPR"
  echo "== Restarting the counter =="
  sudo systemctl enable partcounter >/dev/null 2>&1 || true
  sudo systemctl restart partcounter
  sleep 3
  echo
  echo "Part Counter $(cat "$DIR/VERSION") is running:"
  echo "   http://$(hostname).local:8080"
  for ip in $(hostname -I); do case "$ip" in *:*) ;; *) echo "   http://$ip:8080";; esac; done
else
  bash "$DIR/install.sh"
fi
