# Media Monitor 📼

A lightweight media folder monitor that watches for new files and automatically analyzes them using `ffprobe`, sends formatted notifications using `ntfy.sh`, and avoids duplicate alerts using a simple local database.

---

## Features

✅ Monitors media folders (`Movies` & `Series`)  
✅ Waits for files to finish copying (stable size check)  
✅ Analyzes audio & subtitle language tags with `ffprobe`  
✅ Checks file size thresholds (ex: files > 20GB marked for re-encode)  
✅ Sends pretty notifications using [`ntfy.sh`](https://ntfy.sh/)  
✅ Local deduplication: avoids sending notifications for files already analyzed  
✅ Docker-compatible

---

## Requirements

- Docker (or direct Linux install)
- `ffprobe` (part of `ffmpeg`)
- `jq` (for JSON parsing)
- `ntfy.sh` account or self-hosted instance

---

## Usage

### 1️⃣ Clone the repo

```yaml
services:
  media-monitor:
    image: ivanchelo/ffprobe-ntfy-monitor:latest
    container_name: media_monitor
    restart: unless-stopped
    environment:
      - WATCH_DIR=/watch
      - NTFY_TOPIC=topic-name # <-- replace with your ntfy topic
      - NTFY_SERVER=https://ntfy.sh # <-- replace with your ntfy server if self-hosted
    volumes:
      - /path/to/your/path1:/watch/path1
      - /path/to/your/path2:/watch/path2 # <-- add as many paths as you want inside watch and they will all be monitored
networks: {}