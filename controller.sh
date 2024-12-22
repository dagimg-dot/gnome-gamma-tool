#!/bin/bash

# Script to control monitor brightness with error handling and validation
# Requirements: bc, python3, gnome-gamma-tool

set -euo pipefail # Exit on error, undefined vars, and pipe failures

# Configuration
readonly BRIGHTNESS_FILE="${HOME}/.config/monitor-brightness"
readonly DEFAULT_BRIGHTNESS=1.0
readonly INCREMENT=0.1
readonly MIN_BRIGHTNESS=0.1
readonly MAX_BRIGHTNESS=1.0
readonly SCRIPT_PATH="${HOME}/JDrive/Projects/PYTHON/gnome-gamma-tool/gnome-gamma-tool.py"
readonly MONITOR_SCRIPT_PATH="${HOME}/JDrive/Projects/PYTHON/gnome-gamma-tool/colord.py"

# Check dependencies
check_dependencies() {
  local missing_deps=()

  if ! command -v bc >/dev/null 2>&1; then
    missing_deps+=("bc")
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    missing_deps+=("python3")
  fi

  if [[ ! -f "$SCRIPT_PATH" ]]; then
    echo "Error: gnome-gamma-tool not found at $SCRIPT_PATH" >&2
    echo "Please install it from: https://github.com/zb3/gnome-gamma-tool" >&2
    exit 1
  fi

  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    echo "Error: Missing dependencies: ${missing_deps[*]}" >&2
    echo "Please install them using your package manager." >&2
    exit 1
  fi
}

# Create config directory if it doesn't exist
init_config() {
  local config_dir
  config_dir=$(dirname "$BRIGHTNESS_FILE")

  if [[ ! -d "$config_dir" ]]; then
    mkdir -p "$config_dir" || {
      echo "Error: Failed to create config directory: $config_dir" >&2
      exit 1
    }
  fi
}

# Load the brightness value from the file
load_brightness() {
  if [[ -f "$BRIGHTNESS_FILE" ]]; then
    local stored_brightness
    stored_brightness=$(cat "$BRIGHTNESS_FILE") || {
      echo "Error: Failed to read brightness file" >&2
      exit 1
    }

    BRIGHTNESS=$stored_brightness
  else
    BRIGHTNESS=$DEFAULT_BRIGHTNESS
  fi
}

# Save the brightness value to the file
save_brightness() {
  echo "$BRIGHTNESS" >"$BRIGHTNESS_FILE" || {
    echo "Error: Failed to save brightness value" >&2
    exit 1
  }
}

get_external_monitor() {
  local external_monitor
  external_monitor=$("$MONITOR_SCRIPT_PATH" | jq '.[] | select(.name | contains("HDMI")) | .index')

  echo "$external_monitor"
}

# Apply brightness using gnome-gamma-tool
apply_brightness() {
  local brightness=$1

  # Get the external monitor index
  local external_monitor
  external_monitor=$(get_external_monitor)

  # check if external monitor is not ''
  if [[ -z "$external_monitor" ]]; then
    echo "Error: External monitor not found" >&2
    exit 1
  fi

  # Apply brightness settings
  "$SCRIPT_PATH" -y -d "$external_monitor" -b "$brightness" || {
    echo "Error: Failed to apply brightness settings" >&2
    exit 1
  }
}

# Validate and bound brightness value
validate_brightness() {
  local new_brightness=$1

  # Bound the brightness value
  if (($(echo "$new_brightness < $MIN_BRIGHTNESS" | bc -l))); then
    BRIGHTNESS=$MIN_BRIGHTNESS
    echo "Warning: Minimum brightness reached" >&2
  elif (($(echo "$new_brightness > $MAX_BRIGHTNESS" | bc -l))); then
    BRIGHTNESS=$MAX_BRIGHTNESS
    echo "Warning: Maximum brightness reached" >&2
  else
    BRIGHTNESS=$new_brightness
  fi
}

# Increase brightness
increase_brightness() {
  load_brightness
  local new_brightness
  new_brightness=$(echo "$BRIGHTNESS + $INCREMENT" | bc -l)
  validate_brightness "$new_brightness"
  apply_brightness "$BRIGHTNESS"
  save_brightness
  printf "Brightness increased to %.2f\n" "$BRIGHTNESS"
}

# Decrease brightness
decrease_brightness() {
  load_brightness
  local new_brightness
  new_brightness=$(echo "$BRIGHTNESS - $INCREMENT" | bc -l)
  validate_brightness "$new_brightness"
  apply_brightness "$BRIGHTNESS"
  save_brightness
  printf "Brightness decreased to %.2f\n" "$BRIGHTNESS"
}

# Show current brightness
show_brightness() {
  load_brightness
  notify-send "Current brightness: $BRIGHTNESS"
  printf "Current brightness: %.2f\n" "$BRIGHTNESS"
}

# Show help message
show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTION]
Control monitor brightness.

Options:
  -i, --increase    Increase brightness by $INCREMENT
  -d, --decrease    Decrease brightness by $INCREMENT
  -s, --show        Show current brightness
  -h, --help        Display this help message

Brightness range: $MIN_BRIGHTNESS to $MAX_BRIGHTNESS
Configuration file: $BRIGHTNESS_FILE
EOF
}

# Main function to handle command-line arguments
main() {
  # Check dependencies first
  check_dependencies

  # Initialize config directory
  init_config

  # Process command line arguments
  case "${1:-}" in
  -i | --increase)
    increase_brightness
    ;;
  -d | --decrease)
    decrease_brightness
    ;;
  -s | --show)
    show_brightness
    ;;
  -h | --help)
    show_help
    ;;
  *)
    show_help
    exit 1
    ;;
  esac
}

# Call the main function with all arguments
main "$@"
