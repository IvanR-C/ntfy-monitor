#!/bin/bash

watch_dir=${WATCH_DIR:-/watch}
db_file="./processed.db"
stabilize_interval=10
stabilize_checks=3

wait_for_stable_file() {
  local file="$1"
  local last_size=0
  local stable_count=0

  while true; do
    size=$(stat -c%s "$file" 2>/dev/null)
    if [ "$size" = "$last_size" ]; then
      stable_count=$((stable_count + 1))
      if [ "$stable_count" -ge "$stabilize_checks" ]; then
        break
      fi
    else
      stable_count=0
      last_size="$size"
    fi
    sleep "$stabilize_interval"
  done
}

is_already_processed() {
  local file="$1"
  grep -Fxq "$file" "$db_file" 2>/dev/null
}

mark_as_processed() {
  local file="$1"
  echo "$file" >> "$db_file"
}

analyze_file() {
  local file="$1"
  local title=$(basename "$(dirname "$file")")

  # Skip if already processed
  if is_already_processed "$file"; then
    echo "Already processed: $file"
    return
  fi

  INFO=$(ffprobe -v quiet -print_format json -show_format -show_streams "$file")
  FORMAT=$(echo "$INFO" | jq -r '.format.format_name')
  SIZE=$(stat --printf="%s" "$file")

  STATUS=()
  NEEDS_REMUX=false

  AUDIO_MISSING=$(echo "$INFO" | jq '[.streams[] | select(.codec_type=="audio") | .tags.language // empty] | map(select(. == "")) | length')
  SUB_MISSING=$(echo "$INFO" | jq '[.streams[] | select(.codec_type=="subtitle") | .tags.language // empty] | map(select(. == "")) | length')

  if [ "$AUDIO_MISSING" -gt 0 ] || [ "$SUB_MISSING" -gt 0 ]; then
    NEEDS_REMUX=true
  fi

  if [ "$SIZE" -gt $((20*1024*1024*1024)) ]; then
    STATUS+=("RE-ENCODE")
  fi

  if [ "$NEEDS_REMUX" = true ]; then
    STATUS+=("REMUX")
  fi

  if [ ${#STATUS[@]} -eq 0 ]; then
    STATUS+=("OK")
  fi

  FINAL_STATUS=$(IFS=' | '; echo "${STATUS[*]}")
  payload=$(printf "📦 *File:* %s\n📝 *Result:* %s" "$file" "$FINAL_STATUS")

  curl -X POST \
    -H "Title: $title" \
    -H "Tags: $FORMAT" \
    -d "$payload" "$NTFY_SERVER/$NTFY_TOPIC"

  mark_as_processed "$file"
}

inotifywait -m -r -e close_write,moved_to,create "$watch_dir" --format '%w%f' | while read FILE
do
  if [ -f "$FILE" ]; then
    echo "Detected: $FILE"
    wait_for_stable_file "$FILE"
    analyze_file "$FILE"
  fi
done
