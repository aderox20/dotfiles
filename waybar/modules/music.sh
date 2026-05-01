#!/bin/bash

get_music_info() {
    if playerctl status &>/dev/null; then
        STATUS=$(playerctl status 2>/dev/null)
        if [ "$STATUS" = "Playing" ] || [ "$STATUS" = "Paused" ]; then
            ARTIST=$(playerctl metadata artist 2>/dev/null)
            TITLE=$(playerctl metadata title 2>/dev/null)
            ALBUM=$(playerctl metadata album 2>/dev/null)
            POSITION=$(playerctl position 2>/dev/null | cut -d. -f1)
            DURATION=$(playerctl metadata mpris:length 2>/dev/null | awk '{print int($1/1000000)}')

            # Calculate progress bar
            if [ -n "$POSITION" ] && [ -n "$DURATION" ] && [ "$DURATION" -gt 0 ]; then
                PERCENT=$((POSITION * 100 / DURATION))
                BAR_LENGTH=20
                FILLED=$((PERCENT * BAR_LENGTH / 100))
                EMPTY=$((BAR_LENGTH - FILLED))
                BAR=$(printf "%0.s█" $(seq 1 $FILLED))
                BAR+=$(printf "%0.s░" $(seq 1 $EMPTY))
            else
                BAR=""
                PERCENT=0
            fi

            # Format time
            POS_MIN=$((POSITION / 60))
            POS_SEC=$((POSITION % 60))
            DUR_MIN=$((DURATION / 60))
            DUR_SEC=$((DURATION % 60))
            TIME="${POS_MIN}:$(printf "%02d" $POS_SEC)/${DUR_MIN}:$(printf "%02d" $DUR_SEC)"

            # Truncate if too long
            DISPLAY="$ARTIST - $TITLE"
            if [ ${#DISPLAY} -gt 40 ]; then
                DISPLAY="${DISPLAY:0:37}..."
            fi

            # Icon based on status
            if [ "$STATUS" = "Playing" ]; then
                ICON="\uf04b"
            else
                ICON="\uf04c"
            fi

            echo "{\"text\": \"$ICON $DISPLAY\", \"tooltip\": \"$TITLE\\n$ARTIST\\n$ALBUM\\n\\n$BAR $TIME\", \"class\": \"playing\"}"
        else
            echo "{\"text\": \"\", \"tooltip\": \"No media playing\"}"
        fi
    else
        echo "{\"text\": \"\", \"tooltip\": \"No player found\"}"
    fi
}

get_music_info
