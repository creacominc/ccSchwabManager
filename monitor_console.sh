#!/bin/bash
echo "Monitoring ccSchwabManager console output..."
echo "Press Ctrl+C to stop monitoring"
echo ""

# Monitor console output for the app
log stream --predicate "process == \"ccSchwabManager\"" --info --debug

