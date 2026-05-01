#!/usr/bin/env python3

import gi
gi.require_version('Gtk', '3.0')
gi.require_version('GdkPixbuf', '2.0')
from gi.repository import Gtk, GdkPixbuf, Gdk, GLib
import subprocess
import os
import json
import sys
import threading

CAVA_CONFIG = os.path.expanduser("~/.config/cava/config")

class CavaWidget(Gtk.Box):
    def __init__(self):
        super().__init__(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        self.set_margin_top(2)
        self.set_margin_bottom(2)

        self.artwork = Gtk.Image()
        self.artwork.set_size_request(36, 36)
        self.pack_start(self.artwork, False, False, 0)

        self.info_box = Gtk.VBox(spacing=2)
        self.title_label = Gtk.Label()
        self.title_label.set_ellipsize(3)
        self.title_label.set_max_width_chars(25)
        self.title_label.set_alignment(0, 0.5)

        self.artist_label = Gtk.Label()
        self.artist_label.set_ellipsize(3)
        self.artist_label.set_max_width_chars(25)
        self.artist_label.set_alignment(0, 0.5)
        self.artist_label.get_style_context().add_class("dim-label")

        self.info_box.pack_start(self.title_label, True, True, 0)
        self.info_box.pack_start(self.artist_label, True, True, 0)
        self.pack_start(self.info_box, True, True, 0)

        self.viz_box = Gtk.VBox(spacing=0)
        self.bars = []
        for i in range(8):
            bar = Gtk.DrawingArea()
            bar.set_size_request(4, 36)
            bar.connect("draw", self.draw_bar, i)
            self.bars.append(bar)
            self.viz_box.pack_start(bar, True, True, 0)
        self.pack_start(self.viz_box, False, False, 0)

        self.bar_heights = [0] * 8
        self.current_title = "None playing"
        self.current_artist = ""
        self.artwork_path = ""

        GLib.timeout_add(500, self.update)
        self.start_cava()

    def draw_bar(self, widget, cr, index):
        height = self.bar_heights[index]
        allocation = widget.get_allocation()
        w, h = allocation.width, allocation.height

        cr.set_source_rgb(0.2, 0.6, 1.0)
        if height > 0:
            y = h - (height * h / 36)
            cr.rectangle(0, y, w, height * h / 36)
            cr.fill()

    def update(self):
        self.get_media_info()
        self.get_cava_bars()
        return True

    def get_media_info(self):
        try:
            result = subprocess.run(
                ["playerctl", "metadata", "-f", "{{title}}|{{artist}}|{{mpris:artUrl}}"],
                capture_output=True, text=True, timeout=1
            )
            parts = result.stdout.strip().split('|')
            if len(parts) >= 2:
                self.current_title = parts[0][:30] if parts[0] else "None playing"
                self.current_artist = parts[1][:20] if parts[1] else ""
                self.title_label.set_text(self.current_title)
                self.artist_label.set_text(self.current_artist)

            if len(parts) >= 3 and parts[2]:
                art_url = parts[2].strip()
                if art_url != self.artwork_path:
                    self.artwork_path = art_url
                    self.load_artwork(art_url)
        except:
            self.title_label.set_text("None playing")
            self.artist_label.set_text("")

    def load_artwork(self, url):
        try:
            if url.startswith('file://'):
                path = url[7:]
            elif url.startswith('http'):
                path = None
            else:
                path = url

            if path and os.path.exists(path):
                pix = GdkPixbuf.Pixbuf.new_from_file(path)
                pix = pix.scale_simple(36, 36, 2)
                self.artwork.set_from_pixbuf(pix)
        except:
            pass

    def get_cava_bars(self):
        try:
            with open("/tmp/cava_bars", "r") as f:
                data = json.load(f)
                bars = data.get("bars", [])
                self.bar_heights = bars[:8] if bars else [0] * 8
                for bar in self.bars:
                    bar.queue_draw()
        except:
            self.bar_heights = [0] * 8

    def start_cava(self):
        def run():
            try:
                fifo_dir = "/tmp/cava_fifo"
                os.makedirs(fifo_dir, exist_ok=True)
                fifo = fifo_dir + "/fifo"
                if os.path.exists(fifo):
                    os.remove(fifo)
                os.mkfifo(fifo)

                proc = subprocess.Popen(
                    ["cava", "-p", CAVA_CONFIG],
                    stdout=subprocess.PIPE,
                    stderr=subprocess.DEVNULL
                )
                while True:
                    line = proc.stdout.readline()
                    if line:
                        try:
                            data = json.loads(line)
                            with open("/tmp/cava_bars", "w") as f:
                                json.dump(data, f)
                        except:
                            pass
            except:
                pass

        thread = threading.Thread(target=run, daemon=True)
        thread.start()

class XFCETrayPlugin(Gtk.Box):
    def __init__(self):
        super().__init__()
        self.add(CavaWidget())

def main():
    win = Gtk.Window()
    win.set_title("CAVA Widget")
    win.add(XFCETrayPlugin())
    win.connect("destroy", Gtk.main_quit)
    win.show_all()
    Gtk.main()

if __name__ == "__main__":
    main()