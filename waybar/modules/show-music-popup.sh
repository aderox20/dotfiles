#!/bin/bash

# Kill existing popup if running
pkill -f "yad.*music-popup" && exit 0

if ! playerctl status &>/dev/null; then
    yad --info --title="No Music Playing" --text="No media player active" --timeout=2 --no-buttons --width=250 --height=80 &
    exit 0
fi

STATUS=$(playerctl status 2>/dev/null)
if [ "$STATUS" != "Playing" ] && [ "$STATUS" != "Paused" ]; then
    yad --info --title="No Music Playing" --text="No media playing" --timeout=2 --no-buttons --width=250 --height=80 &
    exit 0
fi

# Get metadata
ARTIST=$(playerctl metadata artist 2>/dev/null)
TITLE=$(playerctl metadata title 2>/dev/null)
ALBUM=$(playerctl metadata album 2>/dev/null)
POSITION=$(playerctl position 2>/dev/null | cut -d. -f1)
DURATION=$(playerctl metadata mpris:length 2>/dev/null | awk '{print int($1/1000000)}')
ART_URL=$(playerctl metadata mpris:artUrl 2>/dev/null)

# Format times
POS_MIN=$((POSITION / 60))
POS_SEC=$((POSITION % 60))
DUR_MIN=$((DURATION / 60))
DUR_SEC=$((DURATION % 60))
TIME_STR="$(printf "%d:%02d" $POS_MIN $POS_SEC) / $(printf "%d:%02d" $DUR_MIN $DUR_SEC)"

# Calculate progress bar (shorter)
if [ -n "$DURATION" ] && [ "$DURATION" -gt 0 ]; then
    PERCENT=$((POSITION * 100 / DURATION))
    BAR_LENGTH=15
    FILLED=$((PERCENT * BAR_LENGTH / 100))
    EMPTY=$((BAR_LENGTH - FILLED))
    BAR=$(printf "%0.s█" $(seq 1 $FILLED))
    BAR+=$(printf "%0.s░" $(seq 1 $EMPTY))
else
    BAR=""
    PERCENT=0
fi

# Handle album art - resize to 180px max width
ART_FILE=""
if [ -n "$ART_URL" ]; then
    if [[ "$ART_URL" == file://* ]]; then
        RAW_PATH="${ART_URL#file://}"
        SRC_FILE=$(python3 -c "import urllib.parse; print(urllib.parse.unquote('$RAW_PATH'))" 2>/dev/null)
        if [ -f "$SRC_FILE" ]; then
            ART_FILE="/tmp/music_art_$$.jpg"
            convert "$SRC_FILE" -resize 180x180 "$ART_FILE" 2>/dev/null
        fi
    elif [[ "$ART_URL" == http* ]]; then
        TMP_FILE="/tmp/music_art_raw_$$.jpg"
        curl -s -L "$ART_URL" -o "$TMP_FILE" 2>/dev/null
        if [ -f "$TMP_FILE" ]; then
            ART_FILE="/tmp/music_art_$$.jpg"
            convert "$TMP_FILE" -resize 180x180 "$ART_FILE" 2>/dev/null
            rm -f "$TMP_FILE"
        fi
    fi
fi

# Create GTK3 settings for pitch black
export HOME="/tmp/yad_home_$$"
mkdir -p "$HOME/.config/gtk-3.0"
cat > "$HOME/.config/gtk-3.0/settings.ini" << 'EOF'
[Settings]
gtk-application-prefer-dark-theme=1
EOF

cat > "$HOME/.config/gtk-3.0/gtk.css" << 'EOF'
window, .background, Yad {
    background-color: #000000;
    color: #ffffff;
}
button {
    background-color: #1a1a1a;
    color: #ffffff;
    border: 1px solid #333333;
}
EOF

export GTK_THEME=""

# Calculate appropriate height - image + text + buttons + padding (compact)
if [ -n "$ART_FILE" ] && [ -f "$ART_FILE" ]; then
    IMG_HEIGHT=$(identify -format "%h" "$ART_FILE" 2>/dev/null || echo "180")
    # Height = image + text area (50) + buttons (30) + padding (20)
    POPUP_HEIGHT=$((IMG_HEIGHT + 100))
    [ "$POPUP_HEIGHT" -gt 280 ] && POPUP_HEIGHT=280
    [ "$POPUP_HEIGHT" -lt 220 ] && POPUP_HEIGHT=220
else
    POPUP_HEIGHT=220
fi

# Build and run yad command
if [ -n "$ART_FILE" ] && [ -f "$ART_FILE" ]; then
    yad --title="♪ Now Playing" \
        --name="music-popup" \
        --class="music-popup" \
        --image="$ART_FILE" \
        --image-on-top \
        --text="<b>$TITLE</b>\n$ARTIST\n\n<i>$ALBUM</i>\n\n$BAR\n$TIME_STR" \
        --button="⏮":1 \
        --button="⏯":2 \
        --button="⏭":3 \
        --button="✖":0 \
        --on-top \
        --skip-taskbar \
        --undecorated \
        --width=250 \
        --height=$POPUP_HEIGHT \
        2>/dev/null &
else
    yad --title="♪ Now Playing" \
        --name="music-popup" \
        --class="music-popup" \
        --image="audio-headphones" \
        --image-on-top \
        --image-width=100 \
        --text="<b>$TITLE</b>\n$ARTIST\n<i>$ALBUM</i>\n$BAR\n$TIME_STR" \
        --button="⏮":1 \
        --button="⏯":2 \
        --button="⏭":3 \
        --button="✖":0 \
        --on-top \
        --skip-taskbar \
        --undecorated \
        --width=250 \
        --height=280 \
        2>/dev/null &
fi

YAD_PID=$!

# Handle button clicks
wait $YAD_PID
case $? in
    1) playerctl previous ;;
    2) playerctl play-pause ;;
    3) playerctl next ;;
esac

# Cleanup
[ -n "$ART_FILE" ] && [[ "$ART_FILE" == /tmp/music_art_* ]] && rm -f "$ART_FILE" 2>/dev/null
rm -rf "$HOME" 2>/dev/null

exit 0
