#!/usr/bin/env bash
set -euo pipefail

# This script runs inside the postgres container during init (executed by official entrypoint)
# It renders the SQL template by replacing placeholders like #{VAR_NAME}# with the current env values
# and writes the final SQL into /docker-entrypoint-initdb.d/01-init-master.sql so it executes afterward.

TEMPLATE_PATH="/tmp/init-master.template.sql"
OUTPUT_PATH="/tmp/01-init-master.sql"

# Ensure defaults so we always support postgres user/db by default
: "${POSTGRES_DB:=postgres}"
: "${POSTGRES_USER:=postgres}"
: "${POSTGRES_PASSWORD:=postgres}"
: "${POSTGRES_REPLICATION_USER:=replicator}"
: "${POSTGRES_REPLICATION_PASSWORD:=replicator123}"
: "${POSTGRES_REPLICATION_SLOT:=replica_slot}"

if [[ ! -f "$TEMPLATE_PATH" ]]; then
  echo "Template not found at $TEMPLATE_PATH; skipping master init rendering" >&2
  exit 0
fi

render() {
  local infile="$1"; shift
  local outfile="$1"; shift

  # Read template
  local content
  content="$(cat "$infile")"

  # Function to safely escape replacement values for sed
  esc_sed() {
    printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'
  }

  # Replace placeholders. Add more vars here if needed.
  declare -A M=(
    [POSTGRES_DB]="$POSTGRES_DB"
    [POSTGRES_USER]="$POSTGRES_USER"
    [POSTGRES_PASSWORD]="$POSTGRES_PASSWORD"
    [POSTGRES_REPLICATION_USER]="$POSTGRES_REPLICATION_USER"
    [POSTGRES_REPLICATION_PASSWORD]="$POSTGRES_REPLICATION_PASSWORD"
    [POSTGRES_REPLICATION_SLOT]="$POSTGRES_REPLICATION_SLOT"
  )

  for key in "${!M[@]}"; do
    val="$(esc_sed "${M[$key]}")"
    # Use a rarely used delimiter | to avoid collisions
    content="$(printf '%s' "$content" | sed -e "s|#{$key}#|$val|g")"
  done

  printf '%s' "$content" > "$outfile"
}

render "$TEMPLATE_PATH" "$OUTPUT_PATH"

# Make sure the generated SQL has correct permissions
chmod 644 "$OUTPUT_PATH"

echo "Rendered init SQL to $OUTPUT_PATH"

# Execute the rendered SQL immediately to avoid relying on writing to /docker-entrypoint-initdb.d
export PGPASSWORD="$POSTGRES_PASSWORD"
psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d postgres -f "$OUTPUT_PATH"
unset PGPASSWORD
