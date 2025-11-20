
#!/bin/bash

CONFIG="$1"
if [ ! -f "$CONFIG" ]; then
  echo "ERROR: ServerConfig.txt not found at $CONFIG"
  kill 1
fi

validate_bool() {
  local value="$1"
  if [[ "$value" != "true" && "$value" != "false" ]]; then
  return 1
  fi
  return 0
}

validate_int() {
  local value="$1"
  local min="$2"
  local max="$3"
  if ! [[ "$value" =~ ^[0-9]+$ ]]; then
  return 1
  fi
  if [ "$value" -lt "$min" ] || [ "$value" -gt "$max" ]; then
  return 1
  fi
  return 0
}

declare -A required_fields=(
  [platforms]=""
  [region]=""
  [starting port]="int:1:65535"
  [username]=""
  [max players]="int:1:64"
)

declare -A optional_fields=(
  [admin code]=""
  [allow votekick]="bool"
  [allow flycam]="bool"
  [match map]=""
  [match type]=""
  [max ping]="int:1:300"
  [max bots]="int:0:64"
  [max score]="int:1:2000"
  [max time]="int:1:120"
  [wait time]="int:1:15"
  [max vehicle]="int:0:10"
  [damage factor]="int:1:3"
  [map destruction]="bool|enabled|disabled"
  [friendly fire]="bool|enabled|disabled"
  [npc difficulty]="int:1:3"
  [transform sync rate]="int:1:3"
)

for key in "${!required_fields[@]}"; do
  value=$(grep -E "^$key=" "$CONFIG" | cut -d'=' -f2)
  if [ -z "$value" ]; then
    echo "ERROR: $key is required!"
  kill 1
  fi
  validation="${required_fields[$key]}"
  if [[ "$validation" == int* ]]; then
    IFS=':' read _ min max <<< "$validation"
    if ! validate_int "$value" "$min" "$max"; then
      echo "ERROR: $key must be an integer between $min and $max!"
      exit 1
    fi
  fi
done

for key in "${!optional_fields[@]}"; do
  value=$(grep -E "^$key=" "$CONFIG" | cut -d'=' -f2)
  if [ -n "$value" ]; then
    validation="${optional_fields[$key]}"
    if [[ "$validation" == "bool" ]]; then
      if ! validate_bool "$value"; then
        echo "ERROR: $key must be true or false!"
        exit 1
      fi
    elif [[ "$validation" == int* ]]; then
      IFS=':' read _ min max <<< "$validation"
      if ! validate_int "$value" "$min" "$max"; then
        echo "ERROR: $key must be an integer between $min and $max!"
        exit 1
      fi
    elif [[ "$validation" == "bool|enabled|disabled" ]]; then
      if [[ "$value" != "true" && "$value" != "false" && "$value" != "enabled" && "$value" != "disabled" ]]; then
        echo "ERROR: $key must be true, false, enabled or disabled!"
        exit 1
      fi
    fi
  fi
done

echo "Configuration is valid."
