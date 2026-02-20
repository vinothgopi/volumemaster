# VolumeMaster

A macOS menu bar app for managing multiple audio outputs. Merge two devices into one, split stereo across speakers, auto-switch devices when USB peripherals connect, and more.

Requires macOS 13.0+

## Why

My desk setup has two external monitors with built-in speakers, an external webcam, and an external mic. Every time I docked my Mac, it picked the wrong devices — wrong speaker, wrong mic, wrong camera. I got tired of manually switching everything.

Then there was the dual-monitor audio problem. I have two displays side by side, both with speakers, but macOS only sends audio to one at a time. The built-in MIDI Audio Setup lets you create an aggregate device to merge them, but the moment you do that, your keyboard volume keys stop working.

VolumeMaster fixes all of this. Profiles auto-switch devices when peripherals connect. Merged output plays through both monitors with working volume keys. And since both monitors are right next to each other, I added spatial audio — the app tracks which monitor has the active window and shifts the audio toward that speaker. It's not a hard switch; it's a spectrum. If a window is slightly left of center, the left monitor plays a bit louder and the right one a bit softer. It sounds surprisingly natural.

## Features

### Multi-Output Merge

Combine two audio outputs into a single virtual device. Audio plays through both simultaneously.

- **Mirror mode** — identical audio on both outputs, with volume synced between them
- **Stereo split** — left channel to one device, right channel to the other (useful for studio monitors or separated speakers)

### Spatial Audio

When using stereo split, VolumeMaster can adjust the left/right balance based on where your active window is on screen. Move a window to the left and the left speaker gets louder. Center it and both play equally. The quieter side never drops below 15%.

### Device Profiles

Create rules that automatically switch your audio setup when USB devices connect or disconnect.

A profile can:
- Set the default output device
- Set the default input device
- Set the preferred webcam
- Enable or disable merge

For example: plug in a USB headset and VolumeMaster auto-switches output and input to it. Unplug it and everything reverts to built-in speakers.

Profiles are also applied on app launch if the trigger device is already connected.

### Media Key Interception

When merge is active, VolumeMaster intercepts the hardware volume keys and applies changes to both outputs. A floating volume HUD shows the current level.

### Menu Bar Interface

Everything lives in the menu bar — no Dock icon. The dropdown shows all connected output and input devices, the current merge status, and the active profile. Switch devices with a single click.

## Installation

1. Download `VolumeMaster.dmg` from the [latest release](https://github.com/vinothgopi/volumemaster/releases/latest)
2. Open the DMG and drag **VolumeMaster** to Applications
3. On first launch, **right-click the app → Open** (required since the app is not yet notarized)
4. Grant **Accessibility** permission when prompted — this is needed for media key interception and window tracking

## Permissions

| Permission | Why |
|---|---|
| **Accessibility** | Intercept media keys and track window positions for spatial audio |
| **Camera** | Set preferred webcam when applying profiles (only requested if a profile uses camera switching) |

## Building from Source

```
git clone https://github.com/vinothgopi/volumemaster.git
cd volumemaster
open VolumeMaster.xcodeproj
```

Build and run in Xcode (15.0+ recommended). The app targets macOS 13.0+.

## Feedback

This is a beta. If you run into bugs or have suggestions, please [open an issue](https://github.com/vinothgopi/volumemaster/issues).

## License

MIT
