# Introduction

Here is a glsl shader for RetroArch. It was built for an Anbernic RG ARC handheld device, but it might be used on other devices too. Some config changes might be required.

# Shader integer-scaler-plus

Integer scaling provides a crisp and clear picture, especially for 8 and 16 bits systems. However, for some systems it leads to wrong aspect ratio,
e.g. scaling SNES games in 256x224 to 640x480 display will be either blurry or shrunk horizontally. To make it even worse, some systems have
multiple resolutions supported, e.g. some games for Sega Genesis switch between 320x224 and 256x224 modes. This makes it hard to tune shaders for
both for crisp picture and correct aspect ratio. That's where integer-scaler-plus can help.

The simplified algorithm is the following:
1. Do vertical integer scale as much as it can. E.g. 224px height will be scaled 2x to 448.
2. Scale horizontally to a screen width or specific pixel aspect ratio. E.g. 320px will be scaled 2x using integer scale, or 256px can be scaled 2.5x to 640px.
   Non-integer scaling may cause some blur, but it usually happens in horizontal direction only. In some displays it can be mitigated with subpixel antialiasing.
3. Add scanlines for CRT effect or dot matrix for pixelated effect.
4. Use some additional features like colorized scanlines for DMG displays or non-integer scaling in both axis in certain cases.

In general, the shader tries it best to do integer scaling when possible to balance between crisp image and correct aspect ratio.

# Installation

The easiest way to try this shader is to run it on a PC with RetroArch installed:
1. Copy shaders to the RetroArch shader folder.
2. Set window size to 640x480 (or to a screen size of your device) in Settings -> Video -> Windowed Mode.
3. Use Full Aspect Ratio in Settings -> Video -> Scaling.
4. Run the game and select a shader in Quick Menu -> Shader -> Load.
5. Try tuning Shader Parameters. Pay attention to the Subpixel config, it should match your screen. There is no visual effect
   in games with integer scaling, so try something with non-integer horizontal scaling, e.g. NES/SNES.

It's possible to install it on a retro emulation device. Currently only one handheld is supported:
- Anbernic RG ARC (in Linux)

It might be possible to use it on other devices based on RetroArch, but I haven't tested it.

## Installing on Anbernic RG ARC Linux

There are 2 ways to use the shader on a device: run it temporarily or install it permanently. Temporary installation is safe and is removed
after device reboot. Anyway, do any changes in your device at your own risk, I'm not responsible for any possible failures.

### Temporary installation

Anbernic RG ARC uses squashfs as a root file system. Squashfs is a read-only file system. You can edit files on it,
but all the changes are in-memory and wiped out after reboot.

The steps are the following:
1. Copy `./shaders` and `./presets/480x640rotatedCW` to a microSD card. A card from TF2/EXT should be Ok.
2. Boot your device.
3. Open File Manager.
4. Copy files you saved in step 1 from `/media/{your_sd_card}/{path_to_files}` to `/usr/share/anbernic/shaders/` (1).
5. Run game in RetroArch.
6. Set Full Aspect Ratio in Settings -> Video -> Scaling.
7. Switch off On-Screen Overlay in Quick Menu.
8. Load a shader in Quick Menu -> Shader -> Load.

(1) Expected file structure after step 4 should be:
```
/usr/share/anbernic/shaders/integer-scaler-plus/shaders/integer-scaler-plus.glsl
/usr/share/anbernic/shaders/integer-scaler-plus/integer-scaler-plus.glslp
/usr/share/anbernic/shaders/integer-scaler-plus/integer-scaler-plus-dotmatrix-1x1.glslp
...
/usr/share/anbernic/shaders/integer-scaler-plus/integer-scaler-plus-scanlines-full.glslp
```

You'll have to repeat steps 6-8 for each new game you load and steps 3-8 after reboot.

### Permanent installation

Permanent installation is baking a temporary installation into a squashfs. To do that you'll need a PC with Linux.

1. Backup your TF1/INT card, so you can restore it in case of any problem. It's an optional step, but highly recommended.
2. Boot Linux on your PC.
3. Insert TF1/INT card to your PC. There should be 3 volumes: `ANBERNIC`, `GAMES`, and `SHARE`.
4. Mount `ANBERNIC` volume.
5. Copy file `/boot/anbernic` from `ANBERNIC` volume to your PC.
6. Unpack squashfs file you copied on previous step with `unsquashfs anbernic` command. Folder `squashfs-root` should be created.
7. Copy `./shaders`, `./presets/480x640rotatedCW`, and `./devices/anbernic_rg_arc_linux/shaders` to a `squashfs-root` folder (1).
8. Backup original squashfs file `mv anbernic anbernic.bak`.
9. Build a new squashfs file with `mksquashfs squashfs-root anbernic` command.
10. Replace original file `/boot/anbernic` from `ANBERNIC` volume with a created one on the previous step.
11. Unmount SD card and insert it to your device.
12. Switch on the device. It should boot Linux as usual.
13. Go to RetroArch, press Start, Game Settings. Set Game Ratio to `4/3`, Integer Scale to `AUTO`, Shader set to `INTEGER-SCALER-PLUS`, Decoration to `NONE`.
14. You're done. Enjoy.

# Known issues

## No known way to get core provided aspect ratio

I can't find a way to get the core provided aspect ratio, neither Screen Aspect Ratio nor Pixel Aspect Ratio.
So the shader tends to switch either to full screen or to square pixels. As a workaround it's possible to set Pixel Aspect Ratio
in Shader Settings, but that may need to be configured per system.

Related issues could be:
- Incorrect aspect ratio if core trims pixels, e.g. truncated 8 pixels from left and 8 pixels prom right in NES games (fixed by shader profile for NES).
- Incorrect aspect ratio in extremely non-square pixels, e.g. Arcade Battletoads is rendered in 512x224 resulting squeezed image (workaround is to manually set 5x8 Pixel Aspect Ratio or use Full Screen Aspect Ratio).
- Incorrect aspect ratio on external monitor or running on non-4/3 Screen device (workaround is to force 4/3 output).

## No options for automatic switching subpixel configuration on external display

I'm not sure how many people use external displays on these devices, so I'll not fix it for now. As a workaround it's always possible to switch options every time the game is run.

## Some games are started with a black screen

I noticed this in some vertical screen arcades, e.g. `1941: Counter Attack`.
Workaround is a Quick Menu -> Shaders -> Apply Changes.
For permanent fix you can edit file config file `/system/configs/retroarch` on volume `SHARE` and set option `video_shader_delay = "20"`.

## Incorrect subpixel antialiasing on rotated screen

Some devices (like Anbernic RG ARC) doesn't provide correct value for `Rotation` for vertical screen games. There is a workaround to detect such cases, 
but there is no way to get a direction of rotation. Parameter `rotated_screen` can be used to detect unset rotation, but direction of a rotation
(CW or CCW) should be selected per game unless subpixel aliasing is switched off.

# License

Provided as is without any warranty.
Free for non-commercial use.
Author: Oleksandr Maksymenko
https://github.com/masyamandev/retroarch_shaders
