
#!/bin/bash

CONFIG="$1"
if [ ! -f "$CONFIG" ]; then
  echo "ERROR: ServerConfig.txt not found at $CONFIG"
  exit 1
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
  [admin code]="numeric"
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
  [anti-cheat]="bool|enabled|disabled"
  [weather override]="string|none|random|clear|rain|snow"
  [optimize network]="bool|true|false"
)

for key in "${!required_fields[@]}"; do
  value=$(grep -iE "^[[:space:]]*$key[[:space:]]*=" "$CONFIG" | head -n 1 | cut -d'=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  if [ -z "$value" ]; then
    echo "ERROR: $key is required!"
    exit 1
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
  value=$(grep -iE "^[[:space:]]*$key[[:space:]]*=" "$CONFIG" | head -n 1 | cut -d'=' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  if [ -n "$value" ]; then
    validation="${optional_fields[$key]}"
    if [[ "$validation" == "bool" ]]; then
      if ! validate_bool "$value"; then
        echo "ERROR: $key must be true or false!"
        exit 1
      fi
    elif [[ "$validation" == "numeric" ]]; then
      if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        echo "ERROR: $key must contain only numbers!"
        exit 1
      fi
    elif [[ "$validation" == int* ]]; then
      IFS=':' read _ min max <<< "$validation"
      if ! validate_int "$value" "$min" "$max"; then
        echo "ERROR: $key must be an integer between $min and $max!"
        exit 1
      fi
    elif [[ "$validation" == *"|"* ]]; then
      type="${validation%%|*}"
      options="${validation#*|}"
      if [[ "$value" =~ ^($options)$ ]]; then
        : 
      elif [[ "$type" == "bool" ]] && validate_bool "$value"; then
        : 
      else
        allowed_list="${options//|/, }"
        [[ "$type" == "bool" && ! "$options" =~ "true" ]] && allowed_list="true, false, $allowed_list"
        echo "ERROR: $key must be one of: $allowed_list!"
        exit 1
      fi
    fi
  fi
done

echo "Configuration is valid."
