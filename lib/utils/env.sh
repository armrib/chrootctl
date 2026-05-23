#!/bin/sh

# Validate an environment variable name
# Returns 0 if valid, 1 if invalid
validate_env_name() {
  local name="$1"

  # Must start with letter or underscore, followed by alphanumerics or underscores
  echo "$name" | grep -qE '^[A-Za-z_][A-Za-z0-9_]*$'
}

# Parse comma-separated KEY=VALUE pairs and validate
# Returns 0 if all valid, 1 if any invalid
# Sets $parsed_env with validated pairs (space-separated)
parse_env_vars() {
  local env_str="$1"
  parsed_env=""

  # Replace commas with spaces for iteration
  local pairs=$(echo "$env_str" | tr ',' ' ')

  for pair in $pairs; do
    # Skip empty pairs
    [ -z "$pair" ] && continue

    # Split by equals
    local name=$(echo "$pair" | cut -d= -f1)
    local value=$(echo "$pair" | cut -d= -f2-)

    # Validate name
    if ! validate_env_name "$name"; then
      return 1
    fi

    # Ensure value is not empty
    if [ -z "$value" ]; then
      return 1
    fi

    parsed_env="$parsed_env$name=$value "
  done

  return 0
}

# Format env vars for .profile export statements
# Takes space-separated KEY=VALUE pairs
# Outputs export statements
format_env_exports() {
  local env_pairs="$1"

  for pair in $env_pairs; do
    local name=$(echo "$pair" | cut -d= -f1)
    local value=$(echo "$pair" | cut -d= -f2-)
    echo "export $name=\"$value\""
  done
}

# Format env vars for shell export (for enter --env)
# Takes space-separated KEY=VALUE pairs
# Outputs shell export commands
export_env_vars() {
  local env_pairs="$1"

  for pair in $env_pairs; do
    local name=$(echo "$pair" | cut -d= -f1)
    local value=$(echo "$pair" | cut -d= -f2-)
    export "$name"="$value"
  done
}
