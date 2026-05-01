#!/bin/bash

# Kill existing popup if running
pkill -f "yad.*music-popup" && exit 0

# Launch yad in background and get PID
GTK_THEME=Adwaita:dark yad --title="♪ Now Playing" \
    --name="music-popup" \
    --class="music-popup" \
    --image="/tmp/music_art_$$.jpg" \
    --image-on-top \
    --image-width=200 \
    --text="Loading..." \
    --button="⏮":1 \
    --button="⏯":2 \
    --button="⏭":3 \
    --button="✖":0 \
    --on-top \
    --skip-taskbar \
    --undecorated \
    --sticky \
    --width=280 \
    --height=350 \
    2>/dev/null &

YAD_PID=$!
sleep 0.5

# Position the window using swaymsg
swaymsg "for_window [app_id=\"music-popup\"] floating enable, border none, opacity 0.95, move position 1086 28"

# Handle button clicks
wait $YAD_PID
case $? in
    1) playerctl previous ;;
    2) playerctl play-pause ;;
    3) playerctl next ;;
esac

exit 0
