/*
Retroarch shader for integer scaling (when possible) + scanlines / dot matrix.

Provided as is without any warranty.
Free for non-commercial use.
Author: Oleksandr Maksymenko
https://github.com/masyamandev/retroarch_shaders
*/

#pragma parameter subpixel_config "Subpixel config: 0:None,1:RGB,2:BGR,3:RGBv,4:BGRv" 0.0 0.0 4.0 1.0
#pragma parameter fract_scale_y_config "Fractional scale Y (0:no,1:1/2,2:1/3,3:1/6,4:any)" 1.0 0.0 4.0 1.0
#pragma parameter fract_scale_y_condition "Fractional scale Y (0:never,1:rotated_scrn,2:always)" 1.0 0.0 2.0 1.0
#pragma parameter rotated_screen "Treat Y > X as (0:normal,1:rotated_CW,2:rotated_CCW)" 1.0 0.0 2.0 1.0
#pragma parameter max_shrink_x "Max shrink X" 0.8 0.5 1.0 0.05
#pragma parameter max_stretch_x "Max stretch X" 1.25 1.0 1.5 0.05
#pragma parameter rotated_stretch_x "Stretch output X in rotated screen" 1.0 1.0 2.0 0.05
#pragma parameter aspect_type "Aspect Ratio type (0:pixel;1:screen,2:full_scrn)" 0.0 0.0 2.0 1.0
#pragma parameter aspect_x "Aspect Ratio X" 5.0 1.0 256. 1.0
#pragma parameter aspect_y "Aspect Ratio Y" 5.0 1.0 256. 1.0
#pragma parameter scanlines_brightness "Scanlines brightness" 0.85 0.0 1.0 0.01
#pragma parameter scanlines_width_y "Scanlines horizontal thickness" 0.3 0.0 0.5 0.1
#pragma parameter scanlines_width_x "Scanlines vertical thickness" 0.0 0.0 0.5 0.1
#pragma parameter scanlines_color_r "Scanlines Color Red" 0.0 0.0 1.0 0.01
#pragma parameter scanlines_color_g "Scanlines Color Green" 0.0 0.0 1.0 0.01
#pragma parameter scanlines_color_b "Scanlines Color Blue" 0.0 0.0 1.0 0.01
#pragma parameter offscreen_texture "Offscreen texture pattern" 1.0 0.0 7.0 1.0


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
COMPAT_VARYING vec4 TEX0;
COMPAT_VARYING vec2 BlurDirection;
COMPAT_VARYING vec2 SubpixelDirection;
COMPAT_VARYING vec2 ScanlineWidth;
COMPAT_VARYING float ScanlineBrightness;
COMPAT_VARYING vec2 InPixelSize;
COMPAT_VARYING vec2 OutPixelSize;
// out variables go here as COMPAT_VARYING whatever

uniform mat4 MVPMatrix;
uniform COMPAT_PRECISION int FrameDirection;
uniform COMPAT_PRECISION int FrameCount;
uniform COMPAT_PRECISION vec2 OutputSize;
uniform COMPAT_PRECISION vec2 TextureSize;
uniform COMPAT_PRECISION vec2 InputSize;
uniform COMPAT_PRECISION int Rotation;

// compatibility #defines
#define vTexCoord TEX0.xy
#define SourceSize vec4(TextureSize, 1.0 / TextureSize) //either TextureSize or InputSize
#define OutSize vec4(OutputSize, 1.0 / OutputSize)

#ifdef PARAMETER_UNIFORM
uniform COMPAT_PRECISION float aspect_type;
uniform COMPAT_PRECISION float aspect_x;
uniform COMPAT_PRECISION float aspect_y;
uniform COMPAT_PRECISION float subpixel_config;
uniform COMPAT_PRECISION float fract_scale_y_config;
uniform COMPAT_PRECISION float fract_scale_y_condition;
uniform COMPAT_PRECISION float rotated_screen;
uniform COMPAT_PRECISION float max_shrink_x;
uniform COMPAT_PRECISION float max_stretch_x;
uniform COMPAT_PRECISION float rotated_stretch_x;
uniform COMPAT_PRECISION float scanlines_brightness;
uniform COMPAT_PRECISION float scanlines_width_x;
uniform COMPAT_PRECISION float scanlines_width_y;
#else
#define aspect_type 1.0
#define aspect_x 64.0
#define aspect_y 64.0
#define subpixel_config 1.0
#define fract_scale_y_config 1.0
#define fract_scale_y_condition 1.0
#define rotated_screen 1.0
#define max_shrink_x 0.8
#define max_stretch_x 1.25
#define rotated_stretch_x 1.0
#define scanlines_brightness 0.85
#define scanlines_width_x 0.0
#define scanlines_width_y 0.3
#endif

#define isRotatedScreen ((Rotation != 0 && Rotation != 2) || (OutputSize.y > OutputSize.x && rotated_screen != 0.0))

float floorScaleY(float scale)
{
    if (fract_scale_y_config == 0.0 || fract_scale_y_condition == 0.0 || (fract_scale_y_condition == 1.0 && !isRotatedScreen)) {
        return floor(scale * 1.001);
    } else if (fract_scale_y_config == 1.0) {
        return floor(scale * 2.001) * 0.5;
    } else if (fract_scale_y_config == 2.0) {
        return floor(scale * 3.001) / 3.0;
    } else if (fract_scale_y_config == 3.0) {
        return floor(scale * 6.001) / 6.0;
    } else {
        return scale;
    }
}

void main()
{
    gl_Position = MVPMatrix * VertexCoord;

    // Calculate constants, same for the whole screen
    int rotation = Rotation;
    if (rotation == 0 && isRotatedScreen) { // Hack for systems which doesn't provide Rotation
        rotation = (rotated_screen > 1.5) ? 3 : 1;
    }
    float rotationAngle = float(rotation) * 3.14159265 * 0.5;
    mat2 rotationMat = mat2(cos(rotationAngle), -sin(rotationAngle), sin(rotationAngle), cos(rotationAngle));

    vec2 scale1x = OutputSize / InputSize;
    float aspect;
    if (aspect_type == 0.0) {
        aspect = aspect_x / aspect_y;
    } else if (aspect_type == 1.0) {
        vec2 scaleRotated = vec2(aspect_x, aspect_y) / InputSize;
        aspect = scaleRotated.x / scaleRotated.y;
    } else {
        vec2 scaleRotated = abs(OutputSize * rotationMat) / InputSize;
        aspect = scaleRotated.x / scaleRotated.y;
    }
    float intScaleBaseY = floorScaleY(scale1x.y);
    float intScaleBaseYX = isRotatedScreen ? floorScaleY(scale1x.x / aspect * rotated_stretch_x) : floorScaleY(scale1x.x / (aspect * max_shrink_x));
    float scaleBaseY = min(intScaleBaseY, intScaleBaseYX);
    float scaleDesiredX = aspect * scaleBaseY;
    float scaleFullWidthX = min(scale1x.x, ceil(scaleDesiredX));
    if (floor(scaleFullWidthX) >= scaleDesiredX * max_shrink_x) {
        scaleFullWidthX = floor(scaleFullWidthX);
    }
    float finalScaleX = (scaleDesiredX * max_stretch_x >= scaleFullWidthX) ? scaleFullWidthX : scaleDesiredX;
    vec2 finalScale = vec2(finalScaleX, scaleBaseY);
    vec2 textureScale = 1.00001 * scale1x / finalScale;

    vec2 centerOffset = floor((OutputSize / finalScale - InputSize) * 0.5) / TextureSize;

    vec2 scanlinesEnabled = step(vec2(2.0, 2.0), finalScale); // Disable scalnines if scaling is < 2x.
    vec2 scalnineWidthPixels = ceil(vec2(scanlines_width_x, scanlines_width_y) * finalScale) * scanlinesEnabled;
    vec2 scanlineWidthAdjusted = 1.0 - scalnineWidthPixels / finalScale;
    float scanlineBrightArea = scanlineWidthAdjusted.x * scanlineWidthAdjusted.y;
    float scanlineRemainingBrightness = max(scanlines_brightness - scanlineBrightArea, 0.0);
    float scanlineBrightnessAdjusted = scanlineRemainingBrightness / max(scanlineRemainingBrightness, 1.0 - scanlineBrightArea);

    vec2 inPixelSize = 1.0 / TextureSize;
    vec2 outPixelSize = inPixelSize / finalScale;

    vec2 subpixelDirection = vec2(0.0, 0.0);
    vec2 blurDirection = clamp(fract(finalScale) * 100.0, vec2(0.01, 0.01), vec2(1.0, 1.0)); // 0 if integer scale and 1 otherwise
    if (subpixel_config == 1.0) {
        subpixelDirection = vec2(-0.333333333, 0.0) * outPixelSize;
    } else if (subpixel_config == 2.0) {
        subpixelDirection = vec2(0.333333333, 0.0) * outPixelSize;
    } else if (subpixel_config == 3.0) {
        subpixelDirection = vec2(0.0, -0.333333333) * outPixelSize;
    } else if (subpixel_config == 4.0) {
        subpixelDirection = vec2(0.0, 0.333333333) * outPixelSize;
    }
    subpixelDirection *= rotationMat;
    subpixelDirection *= blurDirection;
    blurDirection *= outPixelSize * 0.66666666;

    // Transformations
    vec2 finalPosition = TexCoord.xy * textureScale - centerOffset;

    // Outputs
    TEX0.xy = finalPosition;
    SubpixelDirection = subpixelDirection;
    BlurDirection = blurDirection;
    ScanlineWidth = scanlineWidthAdjusted;
    ScanlineBrightness = scanlineBrightnessAdjusted;
    InPixelSize = inPixelSize;
    OutPixelSize = outPixelSize;
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
COMPAT_VARYING vec2 BlurDirection;
COMPAT_VARYING vec2 SubpixelDirection;
COMPAT_VARYING vec2 ScanlineWidth;
COMPAT_VARYING float ScanlineBrightness;
COMPAT_VARYING vec2 InPixelSize;
COMPAT_VARYING vec2 OutPixelSize;
// in variables go here as COMPAT_VARYING whatever

#ifdef PARAMETER_UNIFORM
uniform COMPAT_PRECISION float offscreen_texture;
uniform COMPAT_PRECISION float scanlines_color_r;
uniform COMPAT_PRECISION float scanlines_color_g;
uniform COMPAT_PRECISION float scanlines_color_b;
#else
#define offscreen_texture 1.0
#define scanlines_color_r 0.0
#define scanlines_color_g 0.0
#define scanlines_color_b 0.0
#endif

// compatibility #defines
#define Source Texture
#define vTexCoord TEX0.xy

#define SourceSize vec4(TextureSize, 1.0 / TextureSize) //either TextureSize or InputSize
#define OutSize vec4(OutputSize, 1.0 / OutputSize)


vec3 pixel(sampler2D tex, vec2 pos)
{
    float brightness = (fract(TextureSize.y * pos.y) < ScanlineWidth.y && fract(TextureSize.x * pos.x) < ScanlineWidth.x) ? 1.0 : ScanlineBrightness;
    vec4 pix = COMPAT_TEXTURE(tex, clamp(pos, vec2(0.0, 0.0), InputSize / TextureSize - 0.000001));
	return mix(vec3(scanlines_color_r, scanlines_color_g, scanlines_color_b), pix.rgb, brightness);

    // Debug: draw 1 pixel lines or dot matrix
//    vec2 coords = pos * TextureSize;
//    vec2 dither = fract(vec2(coords.x / 2.0, coords.y / 32.0));
//
//    vec3 color = ((dither.x - 0.5) * (dither.y - 0.5) >= 0.0) ?
//        vec3(1.0, 1.0, 1.0) :
//        vec3(0.0, 0.0, 0.0);
//    return color;

//    vec2 coords = floor(pos * TextureSize);
//    vec3 color = (fract((coords.x + coords.y) / 8.0) == 0.0) ?
//        vec3(1.0, 1.0, 1.0) :
//        vec3(0.0, 0.0, 0.0);
//    return color;
}

vec3 offScreenTexture(vec2 pos)
{
    float PI = 3.1415;

    float brightness = 0.0;

    float pattern = offscreen_texture;

    if (pattern > 3.5) { // 4 pixels of scanlines
        vec2 expandScanlines = 4.0 * InPixelSize;
        vec2 screenSize = InputSize / TextureSize;
        if (pos.x >= -expandScanlines.x && pos.x <= screenSize.x + expandScanlines.x &&
            pos.y >= -expandScanlines.y && pos.y <= screenSize.y + expandScanlines.y) {
            return vec3(scanlines_color_r, scanlines_color_g, scanlines_color_b);
        }
        pattern -= 4.0;
    }

    if (pattern <= 1.1) {
        if (pattern <= 0.1) { // Pattern 0
            brightness = 0.0;
        } else { // Pattern 1
            vec2 transformed = pos / OutPixelSize * mat2(1.0, 1.0, 1.0, -1.0);
            vec2 pattern = abs(cos(transformed * PI * 0.1875));
            brightness = pattern.x * pattern.y;
        }
    } else {
        if (pattern <= 2.1) { // Pattern 2
            vec2 transformed = pos / OutPixelSize * mat2(1.0, 1.0, 1.0, -1.0);
            vec2 pattern = 1.0 - abs(cos(transformed * PI * 0.125));
            brightness = max(pattern.x, pattern.y);
        } else { // Pattern 3
            vec2 transformed = pos / OutPixelSize;
            brightness = abs(cos((transformed.y * 0.25 + sin(transformed.x * PI * 0.125) * 0.5) * PI));
        }
    }

    return vec3(0.1, 0.1, 0.1) * brightness;
}


vec3 getSmoothPixel(vec2 pos) {
    float pixelShrink = 0.0;
    vec2 leftTopCornerOfPixel = floor(pos / InPixelSize) * InPixelSize + InPixelSize * pixelShrink;
    vec2 rightBotCornerOfPixel = leftTopCornerOfPixel + InPixelSize - InPixelSize * pixelShrink;

    vec2 scanlinesPoint = leftTopCornerOfPixel + (rightBotCornerOfPixel - leftTopCornerOfPixel) * ScanlineWidth;
    if (scanlinesPoint.x < pos.x) {
        leftTopCornerOfPixel.x = max(leftTopCornerOfPixel.x, scanlinesPoint.x);
    } else {
        rightBotCornerOfPixel.x = min(rightBotCornerOfPixel.x, scanlinesPoint.x);
    }
    if (scanlinesPoint.y < pos.y) {
        leftTopCornerOfPixel.y = max(leftTopCornerOfPixel.y, scanlinesPoint.y);
    } else {
        rightBotCornerOfPixel.y = min(rightBotCornerOfPixel.y, scanlinesPoint.y);
    }

    leftTopCornerOfPixel = max(leftTopCornerOfPixel, pos - BlurDirection);
    rightBotCornerOfPixel = min(rightBotCornerOfPixel, pos + BlurDirection);
    vec2 centralPixelSize = rightBotCornerOfPixel - leftTopCornerOfPixel;
    vec2 leftTopPixelSize = leftTopCornerOfPixel - (pos - BlurDirection);
    vec2 rightBotPixelSize = (pos + BlurDirection) - rightBotCornerOfPixel;

    vec3 colorOut =
        pixel(Source, pos + vec2(-BlurDirection.x, -BlurDirection.y)) * leftTopPixelSize.x * leftTopPixelSize.y +
        pixel(Source, pos + vec2(0.0, -BlurDirection.y)) * centralPixelSize.x * leftTopPixelSize.y +
        pixel(Source, pos + vec2(BlurDirection.x, -BlurDirection.y)) * rightBotPixelSize.x * leftTopPixelSize.y +
    
        pixel(Source, pos + vec2(-BlurDirection.x, 0.0)) * leftTopPixelSize.x * centralPixelSize.y +
        pixel(Source, pos + vec2(BlurDirection.x, 0.0)) * rightBotPixelSize.x * centralPixelSize.y +
    
        pixel(Source, pos + vec2(-BlurDirection.x, BlurDirection.y)) * leftTopPixelSize.x * rightBotPixelSize.y +
        pixel(Source, pos + vec2(0.0, BlurDirection.y)) * centralPixelSize.x * rightBotPixelSize.y +
        pixel(Source, pos + vec2(BlurDirection.x, BlurDirection.y)) * rightBotPixelSize.x * rightBotPixelSize.y
    ;

    float totalArea = BlurDirection.x * BlurDirection.y * 4.0;
    float centerArea = centralPixelSize.x * centralPixelSize.y;
    float outerArea = max(totalArea - centerArea, totalArea * 0.001);

    vec3 colorCenter = pixel(Source, pos) * centerArea;

//    vec3 color = colorOut + colorCenter;
    vec3 color = mix(colorOut / outerArea, colorCenter / centerArea, centerArea / totalArea) * totalArea;
//    vec3 color = (colorCenter / centerArea) * totalArea;

    color /= BlurDirection.x * BlurDirection.y * 4.0;
    
    return color;
}

void main()
{
    vec2 screenSize = InputSize / TextureSize;

    if (vTexCoord.x < 0.0 || vTexCoord.x > screenSize.x || vTexCoord.y < 0.0 || vTexCoord.y > screenSize.y) {
        vec3 pix = offScreenTexture(vTexCoord);
	    FragColor = vec4(pix, 1.0);
        return;
    }

//    vec2 subpixelDirection = - SubpixelDirection;
//    if (false && fract(floor(vTexCoord.y / OutPixelSize.y) * 0.5) == 0.0)
//    {
//        subpixelDirection *= -1.0;
//    }
//    if (true && mod(float(FrameCount), 2.0) == 0.0)
//    {
//        subpixelDirection *= -1.0;
//    }
//
//    vec3 color0 = pixel(Source, vTexCoord - subpixelDirection * 2.5);
//    vec3 color1 = pixel(Source, vTexCoord - subpixelDirection * 2.0);
//    vec3 color2 = pixel(Source, vTexCoord - subpixelDirection * 1.5);
//    vec3 color3 = pixel(Source, vTexCoord - subpixelDirection * 1.0);
//    vec3 color4 = pixel(Source, vTexCoord - subpixelDirection * 0.5);
//    vec3 color5 = pixel(Source, vTexCoord);
//    vec3 color6 = pixel(Source, vTexCoord + subpixelDirection * 0.5);
//    vec3 color7 = pixel(Source, vTexCoord + subpixelDirection * 1.0);
//    vec3 color8 = pixel(Source, vTexCoord + subpixelDirection * 1.5);
//    vec3 color9 = pixel(Source, vTexCoord + subpixelDirection * 2.0);
//    vec3 colorA = pixel(Source, vTexCoord + subpixelDirection * 2.5);
//
//    vec3 color = vec3(
//            color0.r + color1.r + color2.r + color3.r + color4.r + color5.r + color6.r,
//            color2.g + color3.g + color4.g + color5.g + color6.g + color7.g + color8.g,
//            color4.b + color5.b + color6.b + color7.b + color8.b + color9.b + colorA.b
//        ) / 7.0;

    vec3 color = vec3(
        getSmoothPixel(vTexCoord + SubpixelDirection).r,
        getSmoothPixel(vTexCoord).g,
        getSmoothPixel(vTexCoord - SubpixelDirection).b
    );

    FragColor = vec4(color, 1.0);
}

#endif
