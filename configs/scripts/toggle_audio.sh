#!/bin/bash

# ATTENTION: Device names are customized for my hardware.
# You MUST update these values to match your own devices.
# You can find the correct names by running `wpctl status` and looking for the "Sinks" section.

SPEAKER_NAME="HDMI"
HEADPHONES_NAME="PRO X 2"

SINKS_SECTION=$(wpctl status | sed -n '/Sinks:/,/^$/p')

SPEAKER_ID=$(echo "$SINKS_SECTION" | grep "$SPEAKER_NAME" | grep -oP '\d+(?=\.)' | head -n 1)
HEADPHONES_ID=$(echo "$SINKS_SECTION" | grep "$HEADPHONES_NAME" | grep -oP '\d+(?=\.)' | head -n 1)

CURRENT_ID=$(echo "$SINKS_SECTION" | grep "*" | grep -oP '\d+(?=\.)' | head -n 1)

if [ "$CURRENT_ID" == "$SPEAKER_ID" ]; then
    wpctl set-default "$HEADPHONES_ID"
    notify-send "Audio" "Switched to: ($HEADPHONES_NAME)" --icon=audio-headphones-symbolic
else
    wpctl set-default "$SPEAKER_ID"
    notify-send "Audio" "Switched to: ($SPEAKER_NAME)" --icon=audio-speakers-symbolic
fi