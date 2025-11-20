#!/bin/bash

set -e

if [ ! -z "$TZ" ]; then
  if [ -f "/usr/share/zoneinfo/$TZ" ]; then
    ln -sf "/usr/share/zoneinfo/$TZ" /etc/localtime
    echo "$TZ" > /etc/timezone
    export TZ
    echo "Timezone set to $TZ."
  else
    echo "WARNING: Timezone '$TZ' not found under /usr/share/zoneinfo. Using container default timezone."
  fi
fi

mkdir -p /root/.config/unity3d/Mohammad\ Alizade/Polyfield/editor
mkdir -p /root/.config/unity3d/Mohammad\ Alizade/Polyfield

LATEST_URL=$(wget -qO- https://polyfield.net/builds/ | grep -oP 'Polyfield_v[0-9\.]+_Linux\.zip' | sort -V | tail -n1)
FULL_URL="https://polyfield.net/builds/$LATEST_URL"

if [ -z "$LATEST_URL" ]; then
  echo "ERROR: Could not find the latest Polyfield Linux version."
  exit 1
fi

echo "Downloading Polyfield from $FULL_URL..."
wget -O Polyfield_Linux.zip "$FULL_URL"
unzip -o Polyfield_Linux.zip
chmod +x Polyfield_v*_Linux.x86_64

CONFIG_PATH="/root/.config/unity3d/Mohammad Alizade/Polyfield/ServerConfig.txt"
if [ -d "$CONFIG_PATH" ]; then
  echo "ERROR: $CONFIG_PATH is a directory. It must be a file."
  echo "To fix: Remove the directory and create an empty file with 'rm -rf $CONFIG_PATH && touch $CONFIG_PATH' on your host."
  kill 1
fi

if [ -f "$CONFIG_PATH" ]; then
  echo "ServerConfig.txt found in volume. Checking for environment overrides..."
  CONFIG_KEYS=(
    "platforms"
    "region"
    "starting port"
    "username"
    "admin code"
    "allow votekick"
    "allow flycam"
    "match map"
    "match type"
    "max ping"
    "max players"
    "max bots"
    "max score"
    "max time"
    "wait time"
    "max vehicle"
    "damage factor"
    "map destruction"
    "friendly fire"
    "npc difficulty"
    "transform sync rate"
  )
  TMP_CONFIG="${CONFIG_PATH}.tmp"
  cp "$CONFIG_PATH" "$TMP_CONFIG"
  for key in "${CONFIG_KEYS[@]}"; do
    env_var_name="${key// /_}"
    env_value="${!env_var_name}"
    if [ -n "$env_value" ]; then
      current_value=$(grep -E "^$key=" "$CONFIG_PATH" | cut -d'=' -f2-)
      if [ "$current_value" != "$env_value" ]; then
        echo "Updating $key in ServerConfig.txt: '$current_value' -> '$env_value'"
        sed -i "s|^$key=.*|$key=$env_value|" "$TMP_CONFIG"
      fi
    fi
  done
  mv "$TMP_CONFIG" "$CONFIG_PATH"
fi

if [ ! -f "$CONFIG_PATH" ]; then
  echo "ServerConfig.txt not found. Attempting to create from environment variables..."

  declare -A defaults=(
    [platforms]="Android,IPhonePlayer"
    [admin code]=""
    [allow votekick]="true"
    [allow flycam]="false"
    [match map]="Normandy"
    [match type]="conquest,team death-match"
    [max ping]="300"
    [max players]="64"
    [max bots]="0"
    [max score]="500"
    [max time]="15"
    [wait time]="15"
    [max vehicle]="4"
    [damage factor]="1"
    [map destruction]="enabled"
    [friendly fire]="disabled"
    [npc difficulty]="1"
    [transform sync rate]="3"
  )

  if [ -z "$region" ]; then
    echo "ERROR: region is required and must be set via environment variable."
    kill 1
  fi
  if [ -z "$starting_port" ]; then
    echo "ERROR: starting_port is required and must be set via environment variable."
    kill 1
  fi
  if [ -z "$username" ]; then
    echo "ERROR: username is required and must be set via environment variable."
    kill 1
  fi

  > "$CONFIG_PATH"
  for key in "${CONFIG_KEYS[@]}"; do
    env_var_name="${key// /_}"
    env_value="${!env_var_name}"
    if [ -n "$env_value" ]; then
      value="$env_value"
    else
      value="${defaults[$key]}"
    fi
    echo "$key=$value" >> "$CONFIG_PATH"
  done
  echo "ServerConfig.txt generated from environment variables."
fi

echo "Validating server configuration..."
/validate_config.sh "$CONFIG_PATH"


CONTAINER_ID=$(hostname)

RESTART_ENABLED=${RESTART_ENABLED:-false}

if [ "$RESTART_ENABLED" = "true" ]; then
  if [ -n "$RESTART_INTERVAL_HOURS" ] && [ -n "$RESTART_AT_HOUR" ]; then
    echo "ERROR: Set only one of RESTART_INTERVAL_HOURS or RESTART_AT_HOUR."
    exit 1
  fi

  CRON_FILE="/etc/cron.d/polyfield-restart"
  echo "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" > "$CRON_FILE"

  if [ -n "$RESTART_INTERVAL_HOURS" ]; then
    if ! [[ "$RESTART_INTERVAL_HOURS" =~ ^[1-9][0-9]*$ ]]; then
      echo "ERROR: RESTART_INTERVAL_HOURS must be a positive integer (1-24)."
      exit 1
    fi
    if [ "$RESTART_INTERVAL_HOURS" -gt 24 ]; then
      echo "ERROR: RESTART_INTERVAL_HOURS must be between 1 and 24."
      exit 1
    fi
    INTERVAL="$RESTART_INTERVAL_HOURS"
    echo "0 */$INTERVAL * * * root /bin/touch /tmp/polyfield_restart >> /var/log/polyfield-restart-cron.log 2>&1" >> "$CRON_FILE"
    echo "" >> "$CRON_FILE"
    chmod 0644 "$CRON_FILE"
    echo "Cronjob configured to signal restart every $INTERVAL hours."

  elif [ -n "$RESTART_AT_HOUR" ]; then
    if [[ "$RESTART_AT_HOUR" =~ ^([0-9]|1[0-9]|2[0-3])$ ]]; then
      HOUR="$RESTART_AT_HOUR"
      MINUTE=0
    elif [[ "$RESTART_AT_HOUR" =~ ^([0-1][0-9]|2[0-3]):([0-5][0-9])$ ]]; then
      HOUR="${RESTART_AT_HOUR%%:*}"
      MINUTE="${RESTART_AT_HOUR##*:}"
    else
      echo "ERROR: RESTART_AT_HOUR must be HH or HH:MM (00-23 or 00:00-23:59)."
      exit 1
    fi
    echo "$MINUTE $HOUR * * * root /bin/touch /tmp/polyfield_restart >> /var/log/polyfield-restart-cron.log 2>&1" >> "$CRON_FILE"
    echo "" >> "$CRON_FILE"
    chmod 0644 "$CRON_FILE"
    echo "Cronjob configured to signal restart daily at $(printf '%02d' $HOUR):$(printf '%02d' $MINUTE)."
  else
    echo "RESTART_ENABLED is true but no RESTART_INTERVAL_HOURS or RESTART_AT_HOUR set. Nothing scheduled."
  fi

  if ! pgrep -x cron >/dev/null 2>&1; then
    echo "Starting cron service..."
    cron
    sleep 1
  else
    echo "Cron already running."
  fi
else
  echo "Restart scheduling disabled (RESTART_ENABLED != true)."
fi

echo "Starting Polyfield server supervisor..."

DATA_DIR="/root/.config/unity3d/Mohammad Alizade/Polyfield"
RAW_LOG="$DATA_DIR/server_raw.log"
LOGS_DIR="$DATA_DIR/logs"
mkdir -p "$LOGS_DIR"
mkdir -p "$LOGS_DIR"

ROTATE_RAW_ON_RESTART=${ROTATE_RAW_ON_RESTART:-true}
RAW_LOG_MAX_BYTES=${RAW_LOG_MAX_BYTES:-0}

touch "$RAW_LOG"

LOG_MONITOR_ENABLED=${LOG_MONITOR_ENABLED:-false}
if [ "$LOG_MONITOR_ENABLED" = "true" ] && [ -x /usr/local/bin/polyfield-log-filter.py ]; then
  echo "Starting log monitor..."
  tail -n 0 -F "$RAW_LOG" 2>/dev/null | python3 /usr/local/bin/polyfield-log-filter.py &
  LOG_MONITOR_PID=$!
  echo "Log monitor pid=$LOG_MONITOR_PID"
fi

POLYFIELD_BIN=$(ls Polyfield_v*_Linux.x86_64 | head -n1)

if [ -z "$POLYFIELD_BIN" ]; then
  echo "ERROR: Could not find Polyfield binary to run."
  exit 1
fi

while true; do
  echo "$(date) - Launching ./$POLYFIELD_BIN"
  echo "$(date) - Launching ./$POLYFIELD_BIN" >> "$RAW_LOG"
  ./$POLYFIELD_BIN >> "$RAW_LOG" 2>&1 &
  CHILD_PID=$!

  while kill -0 "$CHILD_PID" >/dev/null 2>&1; do
    if [ -f /tmp/polyfield_restart ]; then
      echo "$(date) - Restart requested (sentinel found)."
      echo "$(date) - Restart requested (sentinel found)." >> "$RAW_LOG"

  TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
 
  JSON_EVENT=$(printf '{"ts":"%s","map":"global","event":"server_restarting","data":{"reason":"scheduled_restart","raw":"Restart requested (sentinel found)"}}' "$TS")
  printf '%s\n' "$JSON_EVENT" >> "$RAW_LOG"

      NEED_ROTATE=1

      rm -f /tmp/polyfield_restart
      kill -TERM "$CHILD_PID" 2>/dev/null || true
      sleep 5
      break
    fi
    sleep 1
  done

  wait "$CHILD_PID" || true
  echo "$(date) - Polyfield process stopped; restarting in 5 seconds..."
  echo "$(date) - Polyfield process stopped; restarting in 5 seconds..." >> "$RAW_LOG"

  if [ "${NEED_ROTATE:-}" = "1" ]; then
    NEED_ROTATE=0
    rm -f "$RAW_LOG" 2>/dev/null || true
    echo "$(date) - Removed raw log prior to restart"
  fi
  sleep 5
done
