#!/bin/bash

get_info() {
    # Check if music is playing
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
                BAR_LENGTH=25
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

            # Show music info in bar
            DISPLAY="$ARTIST - $TITLE"
            if [ ${#DISPLAY} -gt 35 ]; then
                DISPLAY="${DISPLAY:0:32}..."
            fi

            if [ "$STATUS" = "Playing" ]; then
                ICON="\uf04b"
            else
                ICON="\uf04c"
            fi

            TOOLTIP="♪ $TITLE\nby $ARTIST\n$ALBUM\n\n$BAR\n$TIME"
            echo "{\"text\": \"$ICON $DISPLAY\", \"tooltip\": \"$TOOLTIP\", \"class\": \"music-playing\"}"
            return
        fi
    fi

    # Show volume if no music playing
    VOL=$(pamixer --get-volume 2>/dev/null || echo "0")
    MUTED=$(pamixer --get-mute 2>/dev/null || echo "false")

    if [ "$MUTED" = "true" ]; then
        ICON="\uf026"
        TEXT="$ICON Muted"
    else
        if [ "$VOL" -ge 70 ]; then
            ICON="\uf028"
        elif [ "$VOL" -ge 30 ]; then
            ICON="\uf027"
        else
            ICON="\uf026"
        fi
        TEXT="$ICON ${VOL}%"
    fi

    echo "{\"text\": \"$TEXT\", \"tooltip\": \"Volume: ${VOL}%\\nScroll to adjust\\nRight-click to mute\", \"class\": \"volume\"}"
}

get_info
