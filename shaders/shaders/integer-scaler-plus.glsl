// version directive if necessary

// good place for credits/license

#pragma parameter stretch_algo "Stretch algo: 0:Near,1:RGB,2:BGR,3:Line,4:Frame" 1.0 0.0 4.0 1.0
#pragma parameter scanlines_brightness "Scanlines brightness" 0.9 0.5 1.0 0.01
#pragma parameter scanlines_width_y "Scanlines horizontal thickness" 0.3 0.0 0.5 0.1
#pragma parameter scanlines_width_x "Scanlines vertical thickness" 0.0 0.0 0.5 0.1
#pragma parameter max_shrink_x "Max shrink X" 0.8 0.5 1.0 0.05
#pragma parameter max_stretch_x "Max stretch X" 1.25 1.0 1.5 0.05
#pragma parameter aspect_x "Pixel Aspect Ratio X" 5.0 1.0 256. 1.0
#pragma parameter aspect_y "Pixel Aspect Ratio Y" 5.0 1.0 256. 1.0
#pragma parameter offscreen_texture "Offscreen texture pattern" 1.0 0.0 3.0 1.0


#if defined(VERTEX)

#if __VERSION__ >= 130
#define COMPAT_VARYING out
#define COMPAT_ATTRIBUTE in
#define COMPAT_TEXTURE texture
#else
#define COMPAT_VARYING varying
#define COMPAT_ATTRIBUTE attribute
#define COMPAT_TEXTURE texture2D
#endif

#ifdef GL_ES
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

COMPAT_ATTRIBUTE vec4 VertexCoord;
COMPAT_ATTRIBUTE vec4 COLOR;
COMPAT_ATTRIBUTE vec4 TexCoord;
COMPAT_VARYING vec4 COL0;
COMPAT_VARYING vec4 TEX0;
COMPAT_VARYING vec2 TextureScale;
COMPAT_VARYING vec2 SubpixelBlur;
COMPAT_VARYING float SubpixelMirrorEachLine;
COMPAT_VARYING float SubpixelMirrorEachFrame;
COMPAT_VARYING vec2 ScanlineWidth;
COMPAT_VARYING float ScanlineBrightness;
// out variables go here as COMPAT_VARYING whatever

vec4 _oPosition1;
uniform mat4 MVPMatrix;
uniform COMPAT_PRECISION int FrameDirection;
uniform COMPAT_PRECISION int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;

// compatibility #defines
#define vTexCoord TEX0.xy
#define SourceSize vec4(TextureSize, 1.0 / TextureSize) //either TextureSize or InputSize
#define OutSize vec4(OutputSize, 1.0 / OutputSize)

#ifdef PARAMETER_UNIFORM
uniform COMPAT_PRECISION float aspect_x;
uniform COMPAT_PRECISION float aspect_y;
uniform COMPAT_PRECISION float stretch_algo;
uniform COMPAT_PRECISION float max_shrink_x;
uniform COMPAT_PRECISION float max_stretch_x;
uniform COMPAT_PRECISION float scanlines_brightness;
uniform COMPAT_PRECISION float scanlines_width_x;
uniform COMPAT_PRECISION float scanlines_width_y;
#else
#define aspect_x 64.0
#define aspect_y 64.0
#define stretch_algo 1.0
#define max_shrink_x 0.8
#define max_stretch_x 1.25
#define scanlines_brightness 0.9
#define scanlines_width_x 0.0
#define scanlines_width_y 0.3
#endif

void main()
{
    gl_Position = MVPMatrix * VertexCoord;

    // Calculate constants, same for the whole screen
    vec2 FIX = TextureSize.xy / InputSize.xy;

    vec2 scale1x = OutputSize.xy / InputSize.xy;
    vec2 intScaleBase = floor(scale1x);
    float scaleBaseY = min(intScaleBase.y, floor(scale1x.x * aspect_y / aspect_x / max_shrink_x));
    vec2 scaleDesired = vec2(aspect_x / aspect_y * scaleBaseY, scaleBaseY);
    vec2 scaleFullWidth = vec2(scale1x.x, scaleBaseY);
    vec2 finalScale = (scaleDesired.x * max_stretch_x >= scaleFullWidth.x) ? scaleFullWidth : scaleDesired;
    vec2 textureScale = 1.00001 * scale1x / finalScale;

    vec2 centerOffset = (OutputSize.xy / finalScale - InputSize.xy) / InputSize.xy * 0.5 / FIX;

    vec2 subpixelBlur = vec2(1.0 / OutputSize.x, 0.0) / FIX * 0.33333 * min(stretch_algo, 1.0) * ((stretch_algo == 2.0) ? -1.0 : 1.0);

    vec2 ScanlineWidthAdjusted = ceil(vec2(scanlines_width_x, scanlines_width_y) * finalScale) / finalScale;
    float scanlineDarkArea = ScanlineWidthAdjusted.x + ScanlineWidthAdjusted.y - ScanlineWidthAdjusted.x * ScanlineWidthAdjusted.y;
    float scanlineBrightArea = 1.0 - scanlineDarkArea;
    float scanlineRemainingBrightness = max(scanlines_brightness - scanlineBrightArea, 0.0);
    float ScanlineBrightnessAdjusted = scanlineRemainingBrightness / max(scanlineRemainingBrightness, scanlineDarkArea);

    // Transformations
    vec2 finalPosition = TexCoord.xy * textureScale - centerOffset;

    // Outputs
    TEX0.xy = finalPosition;
    TextureScale = textureScale;
    SubpixelBlur = subpixelBlur;
    SubpixelMirrorEachLine = (stretch_algo == 3.0) ? 1.0 : 0.0;
    SubpixelMirrorEachFrame = (stretch_algo == 4.0) ? 1.0 : 0.0;
    ScanlineWidth = ScanlineWidthAdjusted;
    ScanlineBrightness = ScanlineBrightnessAdjusted;
}

#elif defined(FRAGMENT)

#ifdef GL_ES
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif
#define COMPAT_PRECISION mediump
#else
#define COMPAT_PRECISION
#endif

#if __VERSION__ >= 130
#define COMPAT_VARYING in
#define COMPAT_TEXTURE texture
out COMPAT_PRECISION vec4 FragColor;
#else
#define COMPAT_VARYING varying
#define FragColor gl_FragColor
#define COMPAT_TEXTURE texture2D
#endif

uniform COMPAT_PRECISION int FrameDirection;
uniform COMPAT_PRECISION int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;
uniform sampler2D Texture;
COMPAT_VARYING vec4 TEX0;
COMPAT_VARYING vec2 TextureScale;
COMPAT_VARYING vec2 SubpixelBlur;
COMPAT_VARYING float SubpixelMirrorEachLine;
COMPAT_VARYING float SubpixelMirrorEachFrame;
COMPAT_VARYING vec2 ScanlineWidth;
COMPAT_VARYING float ScanlineBrightness;
// in variables go here as COMPAT_VARYING whatever

#ifdef PARAMETER_UNIFORM
uniform COMPAT_PRECISION float offscreen_texture;
#else
#define offscreen_texture 1.0
#endif

// compatibility #defines
#define Source Texture
#define vTexCoord TEX0.xy

#define SourceSize vec4(TextureSize, 1.0 / TextureSize) //either TextureSize or InputSize
#define OutSize vec4(OutputSize, 1.0 / OutputSize)


vec4 pixel(sampler2D tex, vec2 pos)
{
    float brightness = (fract(0.99999 - TextureSize.y * pos.y) < ScanlineWidth.y || fract(0.99999 - TextureSize.x * pos.x) < ScanlineWidth.x) ? ScanlineBrightness : 1.0;
    vec4 pix = COMPAT_TEXTURE(tex, pos);
	return vec4(pix.rgb * brightness, pix.a);
}

vec3 offScreenTexture(vec2 pos)
{
    float PI = 3.1415;

    float brightness = 0.0;

    if (offscreen_texture <= 1.1) {
        if (offscreen_texture <= 0.1) {
            brightness = 0.0;
        } else {
            vec2 transformed = pos.xy * TextureSize.xy * mat2(1.0, 1.0, 1.0, -1.0);
            vec2 pattern = abs(cos(transformed.xy * PI / 2.0));
            brightness = pattern.x * pattern.y;
        }
    } else {
        if (offscreen_texture <= 2.1) {
            vec2 transformed = pos.xy * TextureSize.xy * mat2(1.0, 1.0, 1.0, -1.0);
            vec2 pattern = 1.0 - abs(cos(transformed.xy * PI / 2.0));
            brightness = max(pattern.x, pattern.y);
        } else {
            vec2 transformed = pos.xy * TextureSize.xy;
            brightness = abs(cos((transformed.y + sin(transformed.x * PI / 2.0) * PI * 0.125) * PI / 1.0));
        }
    }
//         vec2 transformed = pos.xy * TextureSize.xy;
// //         brightness = max(cos((transformed.y + sin(transformed.x * PI / 2.0) * PI * 0.25) * PI / 1.0),
// //             cos((transformed.y - sin(transformed.x * PI / 2.0) * PI * 0.25) * PI / 1.0));
//         brightness = abs(cos((transformed.y + sin(transformed.x * PI / 2.0) * PI * 0.25) * PI / 1.0));
//
//         vec2 transformed = pos.xy * TextureSize.xy;
//         vec2 pattern = abs(sin(transformed.xy * PI / 2.0));
//         brightness = pattern.x * pattern.y;

//     if (pos.x > 0.0) brightness = 0.0;

    return vec3(0.1, 0.1, 0.1) * brightness;
}

void main()
{
    vec2 screenSize = InputSize.xy / TextureSize.xy;

    if (vTexCoord.x < 0.0 || vTexCoord.x > screenSize.x || vTexCoord.y < 0.0 || vTexCoord.y > screenSize.y)
    {
        vec3 pix = offScreenTexture(vTexCoord.xy);
	    FragColor = vec4(pix, 1.0);
        return;
    }

    vec2 subpixelBlur = SubpixelBlur;
    vec2 FIX = TextureSize.xy / InputSize.xy;
    if (SubpixelMirrorEachLine > 0.5 && fract(floor(vTexCoord.y / TextureScale.y * OutputSize.y * FIX.y) * 0.5) == 0.0)
    {
        subpixelBlur *= -1.0;
    }
    if (SubpixelMirrorEachFrame > 0.5 && mod(float(FrameCount), 2.0) == 0.0)
    {
        subpixelBlur *= -1.0;
    }

    vec4 color0 = pixel(Source, vTexCoord - subpixelBlur * 2.5);
    vec4 color1 = pixel(Source, vTexCoord - subpixelBlur * 2.0);
    vec4 color2 = pixel(Source, vTexCoord - subpixelBlur * 1.5);
    vec4 color3 = pixel(Source, vTexCoord - subpixelBlur * 1.0);
    vec4 color4 = pixel(Source, vTexCoord - subpixelBlur * 0.5);
    vec4 color5 = pixel(Source, vTexCoord);
    vec4 color6 = pixel(Source, vTexCoord + subpixelBlur * 0.5);
    vec4 color7 = pixel(Source, vTexCoord + subpixelBlur * 1.0);
    vec4 color8 = pixel(Source, vTexCoord + subpixelBlur * 1.5);
    vec4 color9 = pixel(Source, vTexCoord + subpixelBlur * 2.0);
    vec4 colorA = pixel(Source, vTexCoord + subpixelBlur * 2.5);

    vec3 color =
//         (subpixelBlur.x == 0.0 && subpixelBlur.y == 0.0) ?
//         (color0.rgb + color1.rgb + color2.rgb + color3.rgb + color4.rgb + color5.rgb + color6.rgb + color7.rgb + color8.rgb + color9.rgb + colorA.rgb) / 11.0 :
        vec3(
            color0.r + color1.r + color2.r + color3.r + color4.r + color5.r + color6.r,
            color2.g + color3.g + color4.g + color5.g + color6.g + color7.g + color8.g,
            color4.b + color5.b + color6.b + color7.b + color8.b + color9.b + colorA.b
        ) / 7.0;

//     if (experiments == 4.0) {
//         color = (color0.rgb + color1.rgb + color2.rgb + color3.rgb + color4.rgb + color5.rgb + color6.rgb + color7.rgb + color8.rgb + color9.rgb + colorA.rgb) / 11.0;
//     }

    FragColor = vec4(color, color5.a);
}

#endif
