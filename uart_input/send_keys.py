#!/usr/bin/env python3
"""
send_keys.py - PC-side tool for the CHIP-8 FPGA project

SETUP:   pip install pyserial pygame

USAGE 
The FPGA can't read a USB controller or keyboard directly. This script runs on the PC, reads the controller, and sends bytes over the USB-UART
  adapter to the FPGA's uart_receiver module.
  (TO REPLACE COM3 with adapter's port)

  python send_keys.py COM3 keys           type hex digits (0-9, a-f); sends press+release
  python send_keys.py COM3 pad            gamepad (8BitDo) -> press/release events
  python send_keys.py COM3 probe          print gamepad button/hat numbers
                                          (use this to fill in BUTTON_MAP below)
  python send_keys.py COM3 rom pong.ch8   send a ROM file, byte by byte
                                          (the FPGA must be in LOAD mode)

PROTOCOL SENT TO THE FPGA (matches key_input.v), one byte per event:
  0x80 | k  = CHIP-8 key k pressed
  0x00 | k  = CHIP-8 key k released        (k = 0x0 .. 0xF)
"""
import sys, time, serial

BAUD = 115200      # 50 MHz / 115200 = 434)

# ---- gamepad button maps: TO EDIT THESE after running 'probe' -------------------
# Left side = the controller's button/hat number, right side = CHIP-8 key (0x0-0xF).
# These defaults are GUESSES. Different games use different keys (e.g. Pong
# usually uses 1/4 for one paddle and C/D for the other), so change as needed.
BUTTON_MAP = {0: 0x5,    # button 0 (A)  -> key 5
              1: 0x0,    # button 1 (B)  -> key 0
              2: 0x1,    # button 2 (X)  -> key 1
              3: 0xC}    # button 3 (Y)  -> key C
HAT_MAP = {"up": 0x2, "down": 0x8, "left": 0x4, "right": 0x6}   # D-pad

def press(ser, k):
    """Tell the FPGA that CHIP-8 key k is now held down."""
    ser.write(bytes([0x80 | k]))

def release(ser, k):
    """Tell the FPGA that CHIP-8 key k was let go."""
    ser.write(bytes([k]))

def run_pad(ser, probe=False):
    """Read the gamepad with pygame and forward press/release events.
       With probe=True, only print what each button/D-pad press looks like."""
    import pygame
    pygame.init(); pygame.joystick.init()
    if pygame.joystick.get_count() == 0:
        print("No gamepad found. Plug it in by USB (wired mode)."); return
    js = pygame.joystick.Joystick(0); js.init()
    print("Using:", js.get_name(), "(Ctrl+C to quit)")
    hat_prev = (0, 0)                       # last D-pad position, to detect changes
    while True:
        for e in pygame.event.get():
            if probe:                       # probe mode: just show the events
                if e.type in (pygame.JOYBUTTONDOWN, pygame.JOYBUTTONUP, pygame.JOYHATMOTION):
                    print(e)
                continue
            # normal buttons
            if e.type == pygame.JOYBUTTONDOWN and e.button in BUTTON_MAP:
                press(ser, BUTTON_MAP[e.button])
            elif e.type == pygame.JOYBUTTONUP and e.button in BUTTON_MAP:
                release(ser, BUTTON_MAP[e.button])
            # D-pad ("hat"): value is (x, y) with each in {-1, 0, 1}
            elif e.type == pygame.JOYHATMOTION:
                x, y = e.value; px, py = hat_prev
                for cur, prev, name_pos, name_neg in ((x, px, "right", "left"),
                                                      (y, py, "up", "down")):
                    if prev != cur:         # this axis changed: release old, press new
                        if prev ==  1: release(ser, HAT_MAP[name_pos])
                        if prev == -1: release(ser, HAT_MAP[name_neg])
                        if cur  ==  1: press(ser, HAT_MAP[name_pos])
                        if cur  == -1: press(ser, HAT_MAP[name_neg])
                hat_prev = (x, y)
        time.sleep(0.005)                   # don't hog the CPU

def main():
    if len(sys.argv) < 3:
        print(__doc__); return
    port, mode = sys.argv[1], sys.argv[2]
    ser = serial.Serial(port, BAUD, bytesize=8, parity='N', stopbits=1)

    if mode == "keys":                      # keyboard test mode
        print("Type hex digits (0-9, a-f), Enter to send, Ctrl+C to quit.")
        while True:
            for ch in input("> ").strip().lower():
                if ch in "0123456789abcdef":
                    k = int(ch, 16)
                    press(ser, k); time.sleep(0.1)     # hold ~100 ms
                    release(ser, k); time.sleep(0.02)

    elif mode in ("pad", "probe"):          # gamepad modes
        run_pad(ser, probe=(mode == "probe"))

    elif mode == "rom":                     # send a game file to the ROM loader
        data = open(sys.argv[3], "rb").read()
        print(f"Sending {len(data)} bytes...")
        for b in data:
            ser.write(bytes([b]))
            time.sleep(0.001)               # 1 ms gap so the loader keeps up
        print("Done.")

    ser.close()

if __name__ == "__main__":
    main()
