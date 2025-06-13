FROM alpine:latest

# Install only what's needed
RUN apk add --no-cache ffmpeg inotify-tools curl coreutils

# Copy the monitoring script into container
COPY monitor.sh /monitor.sh

# Make sure it's executable
RUN chmod +x /monitor.sh

# Run monitor
ENTRYPOINT ["/monitor.sh"]
