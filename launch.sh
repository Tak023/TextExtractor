#!/bin/bash
# Launch TextExtractor directly (works better with permissions)
pkill -x TextExtractor 2>/dev/null
sleep 0.5
/Applications/TextExtractor.app/Contents/MacOS/TextExtractor &
echo "TextExtractor launched. Look for 📋 in menu bar."
