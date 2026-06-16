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
  [anti-cheat]="enabled"
  [weather override]="none"
  [optimize network]="true"
)

PRESERVE_DATA_ON_UPDATE=${PRESERVE_DATA_ON_UPDATE:-true}

export DATA_DIR="/root"
mkdir -p "$DATA_DIR/editor" "$DATA_DIR/logs"

cd "$DATA_DIR"

LATEST_URL=$(wget -qO- https://polyfield.net/builds/ | grep -oP 'Polyfield_v[0-9.]+_Linux.*?\.zip' | sort -V | tail -n1) || { echo "ERROR: Could not fetch builds list"; exit 1; }
FULL_URL="https://polyfield.net/builds/$LATEST_URL"

if [ -z "$LATEST_URL" ]; then
  echo "ERROR: Could not find the latest Polyfield Linux version."
  exit 1
fi

VERSION_FILE="$DATA_DIR/.server_version"
INSTALLED_VERSION=$(cat "$VERSION_FILE" 2>/dev/null || echo "")
MANIFEST_FILE="$DATA_DIR/.server_manifest"
CURRENT_BIN=$(ls "$DATA_DIR"/Polyfield_v*_Linux*.x86_64 2>/dev/null | head -n1)

if [ -n "$CURRENT_BIN" ] && [ "$INSTALLED_VERSION" == "$LATEST_URL" ] && [ -f "$MANIFEST_FILE" ]; then
  echo "Latest version ($(basename "$CURRENT_BIN")) is already installed in volume. Skipping download."
else
  echo "New version detected or binary missing. Downloading from $FULL_URL..."
  
  if [ -f "$MANIFEST_FILE" ]; then
    if [ "$PRESERVE_DATA_ON_UPDATE" = "false" ]; then
      echo "Cleaning up previous version completely..."
      while IFS= read -r file; do
        [ -n "$file" ] && rm -rf "$file"
      done < "$MANIFEST_FILE"
    else
      echo "Cleaning up previous version using manifest, preserving user data..."
      while IFS= read -r file; do
        if [[ "$file" == "editor/"* || "$file" == "logs/"* || "$file" == "editor" || "$file" == "logs" || "$file" == "ServerConfig.txt" || "$file" == "banned-users.txt" ]]; then
          continue
        fi
        [ -n "$file" ] && rm -rf "$file"
      done < "$MANIFEST_FILE"
    fi
  fi
  
  rm -f Polyfield_v*_Linux*.x86_64 GameAssembly.so UnityPlayer.so
  rm -rf Polyfield_v*_Linux*_Data
  wget -q -O "Polyfield_Linux.zip" "$FULL_URL"
  echo "Download complete. Extracting files..."
  unzip -Z1 "Polyfield_Linux.zip" > "$MANIFEST_FILE"
  unzip -qo "Polyfield_Linux.zip"
  echo "Extraction complete."
  rm "Polyfield_Linux.zip"
  NEW_BIN=$(ls "$DATA_DIR"/Polyfield_v*_Linux*.x86_64 | head -n1)
  [ -n "$NEW_BIN" ] && chmod +x "$NEW_BIN"
  echo "$LATEST_URL" > "$VERSION_FILE"
fi

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
  "anti-cheat"
  "weather override"
  "optimize network"
)

CONFIG_PATH="$DATA_DIR/ServerConfig.txt"
if [ -d "$CONFIG_PATH" ]; then
  echo "ERROR: $CONFIG_PATH is a directory. It must be a file."
  echo "To fix: Remove the directory and create an empty file with 'rm -rf $CONFIG_PATH && touch $CONFIG_PATH' on your host."
  exit 1
fi

echo "Processing ServerConfig.txt..."
declare -A current_config_values
if [ -f "$CONFIG_PATH" ]; then
  echo "Existing ServerConfig.txt found. Reading current values."
  while IFS='=' read -r key value; do
    key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    if [[ "$key" =~ ^[[:alnum:][:space:]-]+$ && ! "$key" =~ ^# ]]; then
      current_config_values["$key"]="$value"
    fi
  done < "$CONFIG_PATH"
else
  echo "ServerConfig.txt not found. Creating a new one."
fi

TMP_CONFIG="${CONFIG_PATH}.tmp"
> "$TMP_CONFIG"

for key in "${CONFIG_KEYS[@]}"; do
  env_var_name="${key//[ -]/_}"
  env_value="${!env_var_name}"
  
  local_value=""
  if [ -n "$env_value" ]; then
    local_value="$env_value"
  elif [ -n "${current_config_values[$key]}" ]; then
    local_value="${current_config_values[$key]}"
  elif [ -n "${defaults[$key]}" ]; then
    local_value="${defaults[$key]}"
  fi

  if [ -n "$env_value" ] && [ "${current_config_values[$key]}" != "$env_value" ]; then
    echo "Updating $key in ServerConfig.txt: '${current_config_values[$key]}' -> '$env_value'"
  elif [ -z "$env_value" ] && [ -z "${current_config_values[$key]}" ] && [ -n "${defaults[$key]}" ]; then
    echo "Setting $key in ServerConfig.txt to default: '${defaults[$key]}'"
  elif [ -z "$env_value" ] && [ -n "${current_config_values[$key]}" ]; then
    echo "Keeping $key in ServerConfig.txt: '${current_config_values[$key]}'"
  fi
  echo "$key=$local_value" >> "$TMP_CONFIG"
done
mv "$TMP_CONFIG" "$CONFIG_PATH"

if [ -z "$region" ]; then
  echo "ERROR: region is required and must be set via environment variable."
  exit 1
fi
if [ -z "$starting_port" ]; then
  echo "ERROR: starting_port is required and must be set via environment variable."
  exit 1
fi
if [ -z "$username" ]; then
  echo "ERROR: username is required and must be set via environment variable."
  exit 1
fi

echo "Validating server configuration..."
/validate_config.sh "$CONFIG_PATH"


CONTAINER_ID=$(hostname)

RESTART_REASON="Manual or external request."
if [ "$RESTART_ENABLED" = "true" ]; then
  if [ -n "$RESTART_INTERVAL_HOURS" ]; then
    RESTART_REASON="Configured to restart every $RESTART_INTERVAL_HOURS hours."
  elif [ -n "$RESTART_AT_HOUR" ]; then
    RESTART_REASON="Configured to restart at $RESTART_AT_HOUR $TZ."
  fi
fi

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
  echo "Cronjob configured to signal restart daily at $(printf '%02d' $((10#$HOUR))):$(printf '%02d' $((10#$MINUTE)))."
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

RAW_LOG="$DATA_DIR/server_raw.log"
LOGS_DIR="$DATA_DIR/logs"
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

POLYFIELD_BIN=$(ls "$DATA_DIR"/Polyfield_v*_Linux*.x86_64 | head -n1)

if [ -z "$POLYFIELD_BIN" ]; then
  echo "ERROR: Could not find Polyfield binary to run."
  exit 1
fi

while true; do
  BIN_NAME=$(basename "$POLYFIELD_BIN")
  echo "$(date) - Launching $BIN_NAME from volume"
  echo "$(date) - Launching $BIN_NAME from volume" >> "$RAW_LOG"
  
  cd "$DATA_DIR"
  ./"$BIN_NAME" >> "$RAW_LOG" 2>&1 &
  CHILD_PID=$!

  while kill -0 "$CHILD_PID" >/dev/null 2>&1; do
    if [ -f /tmp/polyfield_restart ]; then
      if [ "$LOG_MONITOR_ENABLED" = "true" ]; then
        if [ ! -f /tmp/polyfield_restart_ready ]; then
          sleep 2
          continue
        fi
      fi

      echo "$(date) - Restart requested (sentinel found)."
      echo "$(date) - Restart requested (sentinel found)." >> "$RAW_LOG"

      for i in 5 4 3 2 1; do
        echo "server_restarting: The server will restart in $i seconds." >> "$RAW_LOG"
        sleep 1
      done

      echo "server_restarting: Restart requested (sentinel found). Reason: $RESTART_REASON" >> "$RAW_LOG"

      NEED_ROTATE=1

      rm -f /tmp/polyfield_restart /tmp/polyfield_restart_ready
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
