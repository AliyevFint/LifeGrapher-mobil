#!/usr/bin/env zsh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLIST_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="$PLIST_DIR/com.lifegrapher.dailycommit.plist"

mkdir -p "$PLIST_DIR"

cat > "$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>com.lifegrapher.dailycommit</string>

    <key>ProgramArguments</key>
    <array>
      <string>/bin/zsh</string>
      <string>$PROJECT_DIR/scripts/auto_commit.sh</string>
    </array>

    <key>WorkingDirectory</key>
    <string>$PROJECT_DIR</string>

    <key>StandardOutPath</key>
    <string>$PROJECT_DIR/logs/daily_commit.out.log</string>
    <key>StandardErrorPath</key>
    <string>$PROJECT_DIR/logs/daily_commit.err.log</string>

    <key>StartCalendarInterval</key>
    <dict>
      <key>Hour</key>
      <integer>21</integer>
      <key>Minute</key>
      <integer>0</integer>
    </dict>

    <key>RunAtLoad</key>
    <false/>
  </dict>
</plist>
EOF

mkdir -p "$PROJECT_DIR/logs"
launchctl unload "$PLIST_PATH" >/dev/null 2>&1 || true
launchctl load "$PLIST_PATH"

echo "Installed daily commit scheduler at 21:00 local time."
echo "Plist: $PLIST_PATH"
