#!/usr/bin/env python3
"""
Mobile Vault – procedural Kairosoft-style pixel-art generator (true pixel: one master palette, no scaling).

Generates every texture the game needs:
  assets/atlas/atlas.png + atlas.json   all small sprites (truck, rooms, dwellers, enemies, icons...)
  assets/bg/<biome>_<layer>.png          tall seamless parallax layers (sky strip, sun, clouds, far, mid, near, road)
  assets/bg/v2/<biome>_*.png + .json     v2 layered backgrounds at real scale (tools/art/bg2.py, MV-163)
  assets/inspect/*.png                   stranger-at-the-door portrait layers + 96x48 check close-ups
  assets/events/<event>.png              160x80 event illustrations (enc_*: expedition special encounters)
  assets/ui/*.png                        Kairosoft-style cream/brown 9-slice frames

Run:  python3 tools/generate_pixel_art.py      (needs Pillow)
"""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from art.common import pack_atlas, OUT_ATLAS
from art import rooms, truck, engine_bay, chars, ui, bg, bg2, events, landmarks, extra, expedition, inspect, encounters


def main():
    rooms.gen_rooms()
    truck.gen_truck()
    engine_bay.gen_engine_bay()
    dvars = chars.gen_dwellers()
    chars.gen_enemies()
    chars.gen_bosses()
    landmarks.gen_landmarks()
    chars.gen_pets()
    extra.gen_extra()
    expedition.gen_expedition()
    ui.gen_icons()
    ui.gen_particles()
    ui.gen_combat_props()
    ui.gen_ui_frames()
    pack_atlas()
    bg.gen_backgrounds()
    bg2.gen_backgrounds_v2()
    events.gen_events()
    inspect.gen_inspect()
    encounters.gen_encounters()
    with open(os.path.join(OUT_ATLAS, "dweller_variants.json"), "w") as f:
        json.dump(dvars, f)
    print("done")


if __name__ == "__main__":
    main()
