# Introduction

Here is a glsl shader for RetroArch. It was build for a Anbernic RG ARC handheld device, but it might be used on other devices too. Some config changes might be required.

# Shader integer-scaler-plus

Integer scaling provides crisp and clear picture, especially for 8 and 16 bits systems. However, for some systems it leads to wrong aspect ratio, 
e.g. scaling SNES games in 256x224 to 640x480 display will be either blurry or shrunk horizontally. To make it even worse, some systems have 
multiple resolutions supported, e.g. some games for Sega Genesis switch between 320x224 and 256x224 modes. This makes it hard to tune shaders for
both for crisp picture and correct aspect ratio. That's where integer-scaler-plus can help.

The simplified algorithm is the following:
1. Do vertical integer scale as much as it can. E.g. 224px height will be scaled 2x to 448.
2. Scale horizontally to a screen width or specific pixel aspect ratio. E.g. 320px will be scaled 2x using integer scale, or 256px can be scaled 2.5x to 640px. 
Non-integer scaling may cause some blur, but it's usually happen in horizontal direction only. In some displays it can be mitigated with subpixel antialiasing.
3. Add scanlines for CRT effect or dot matrix for pixelated effect.
4. Use some additional features like colorized scanlines for DMG displays or non-integer scaling in both axis in certain case.

In general, the shader tries it best to do integer scaling when possible to balance between crisp image and correct aspect ratio.

# License

Provided as is without any warranty.
Free for non-commercial use.
Author: Oleksandr Maksymenko
https://github.com/masyamandev/retroarch_shaders
