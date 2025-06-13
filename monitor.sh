#!/bin/sh

watch_dir=${WATCH_DIR:-/watch}
stabilize_interval=10  # seconds between checks
stabilize_checks=3     # how many times size must stay stable

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

analyze_file() {
  local file="$1"
  local title=$(basename "$(dirname "$file")")

  INFO=$(ffprobe -v quiet -print_format json -show_format -show_streams "$file")
  FORMAT=$(echo "$INFO" | jq -r '.format.format_name')
  SIZE=$(stat --printf="%s" "$file")

  STATUS=()
  NEEDS_REMUX=()

  if [ "$AUDIO_MISSING" -gt 0 ] || [ "$SUB_MISSING" -gt 0 ]; then
    NEEDS_REMUX=true
  fi

  if [ "$SIZE" -gt $((20*1024*1024*1024)) ]; then
    STATUS+=("RE-ENCODE")
  fi

  # Check remux condition
  if [ "$NEEDS_REMUX" = true ]; then
      STATUS+=("REMUX")
  fi

  # If none applied
  if [ ${#STATUS[@]} -eq 0 ]; then
      STATUS+=("OK")
  fi

  # curl -X POST -H "Title: $title" -d "Result: $STATUS\nReason: $REASON" "$NTFY_SERVER/$NTFY_TOPIC"

  FINAL_STATUS=$(IFS=' | '; echo "${STATUS[*]}")
  payload=$(printf "📦 *File:* %s\n📝 *Result:* %s\n🎯 *Reason:* %s" "$file" "$FINAL_STATUS" "$REASON")

  curl -X POST \
    -H "Title: $title" \
    -H "Tags: $format" \
    -d "$payload" "$NTFY_SERVER/$NTFY_TOPIC"
  }

inotifywait -m -r -e close_write,moved_to,create "$watch_dir" --format '%w%f' | while read FILE
do
  if [ -f "$FILE" ]; then
    echo "Detected: $FILE"
    echo "Format: $FORMAT"
    wait_for_stable_file "$FILE"
    analyze_file "$FILE"
  fi
done
