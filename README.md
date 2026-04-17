# Tape

Tape is a tiny macOS menu bar app for quickly switching your default audio output
between your normal device and `Multi-Output Device`. So you can quickly record anything that currently plays on your mac to Oceanaudio, Audacity or any other audio software. Happy ripping and sampling!

## Prerequisites for running
- install BlackHole Audio Loopback
- check https://github.com/ExistentialAudio/BlackHole/wiki/Multi-Output-Device

## What it does

- Left click the menu bar icon to toggle modes.
- In default mode, the icon shows a speaker.
- In record mode, the icon shows a tape-like symbol and switches output to
  `Multi-Output Device`.
- When entering record mode, Tape remembers the previous default output device.
- When leaving record mode, Tape restores that previous output device.
- Right click the icon for `Default Mode`, `Record Mode`, or `Quit`.

## Build

Run:

```bash
./build-tape.sh
```

This creates `Tape.app` in the project root.

## Notes

- Tape only changes the default output device. It does not touch your input
  device, so your MacBook Pro microphone can stay selected.
- The app expects an output device named exactly `Multi-Output Device`.
- If the previous output device is no longer available, Tape will show an error.
