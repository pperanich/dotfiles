#!/bin/bash
# Build mapping between aerospace NSScreen IDs and sketchybar display numbers
# Output format: nsscreen_id|sketchybar_display (one per line)

python3 <<'PYTHON'
import subprocess
import json

# Get NSScreen positions via JXA
# NSScreen.screens[0] is always the main display (where the menu bar is)
# This corresponds to sketchybar display 1
jxa_result = subprocess.run([
    'osascript', '-l', 'JavaScript', '-e', '''
ObjC.import('AppKit');
var screens = $.NSScreen.screens;
var result = [];
for (var i = 0; i < screens.count; i++) {
    var screen = screens.objectAtIndex(i);
    var frame = screen.frame;
    // aerospace NSScreen ID is 1-indexed array position
    var nsscreenId = i + 1;
    var isMain = (i === 0);
    result.push(JSON.stringify({id: nsscreenId, x: Math.floor(frame.origin.x), isMain: isMain}));
}
"[" + result.join(",") + "]";
'''
], capture_output=True, text=True)
nsscreens = json.loads(jxa_result.stdout.strip())
num_screens = len(nsscreens)

# Create probes on each sketchybar display
for d in range(1, num_screens + 1):
    subprocess.run(['sketchybar', '--add', 'item', f'__probe_{d}', 'center',
                   '--set', f'__probe_{d}', f'display={d}', 'icon.drawing=off',
                   'label.drawing=off', 'width=0'], capture_output=True)

import time
time.sleep(0.2)

sbar_displays = []
for d in range(1, num_screens + 1):
    result = subprocess.run(['sketchybar', '--query', f'__probe_{d}'], capture_output=True, text=True)
    subprocess.run(['sketchybar', '--remove', f'__probe_{d}'], capture_output=True)
    try:
        data = json.loads(result.stdout)
        rects = data.get('bounding_rects', {})
        for disp, rect in rects.items():
            origin = rect.get('origin', [-9999, -9999])
            if origin[0] > -9000:
                sbar_displays.append({'id': d, 'x': int(origin[0])})
                break
    except:
        pass

# The main NSScreen (index 0) maps to sketchybar display 1
# NSScreen.screens[0] is always the main display in Cocoa
# and sketchybar display 1 is always the main display

# For non-main displays, sort by x and match
main_ns = next(ns for ns in nsscreens if ns['isMain'])
other_ns = sorted([ns for ns in nsscreens if not ns['isMain']], key=lambda x: x['x'])

# sketchybar display 1 is main, others sorted by x
main_sbar = next((s for s in sbar_displays if s['id'] == 1), None)
other_sbar = sorted([s for s in sbar_displays if s['id'] != 1], key=lambda x: x['x'])

# Output mapping
print(f"{main_ns['id']}|1")
for ns, sbar in zip(other_ns, other_sbar):
    print(f"{ns['id']}|{sbar['id']}")
PYTHON
