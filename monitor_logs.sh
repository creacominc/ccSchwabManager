#!/bin/bash
echo "Monitoring ccSchwabManager.log for new entries..."
echo "Press Ctrl+C to stop monitoring"
echo ""

# Get the log file path
LOG_FILE="$HOME/Documents/ccSchwabManager.log"

# Check if log file exists
if [ ! -f "$LOG_FILE" ]; then
    echo "Log file not found at: $LOG_FILE"
    echo "Creating empty log file..."
    touch "$LOG_FILE"
fi

# Monitor the log file for new entries
tail -f "$LOG_FILE" | while read line; do
    echo "[$(date +"%H:%M:%S")] $line"
done

