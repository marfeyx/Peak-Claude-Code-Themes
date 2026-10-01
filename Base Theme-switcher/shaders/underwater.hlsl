// Underwater effect for Windows Terminal, applied via experimental.pixelShaderPath.
//
// The whole window is open water: a depth gradient, animated caustics, surface
// light shafts and rising bubbles. The terminal is sampled on-grid: any
// refraction offset resamples the texture off-texel and smears pixel art.
// Pixels matching the sentinel magenta are replaced by a clone of the terminal a
// couple of rows away, which erases the Claude Code message backgrounds without
// leaving an opaque streak on a translucent window.
//
// Text luminance is preserved, so the terminal stays readable over the water.

Texture2D shaderTexture;
SamplerState samplerState;

cbuffer PixelShaderSettings
{
    float  Time;
    float  Scale;
    float2 Resolution;
    float4 Background;
};

static const float CAUSTIC_SCALE = 6.0;
static const int   BUBBLE_COUNT = 9;

static const float3 ERASE_KEY = float3(1.0, 0.0, 1.0);
static const float  ERASE_TOLERANCE = 0.15;
static const float  CLONE_DISTANCE = 26.0;

float CausticField(float2 probe, float time)
{
    float value = 0.0;
    value += sin(probe.x * 1.7 + time * 0.80 + sin(probe.y * 1.3 - time * 0.60) * 1.8);
    value += sin(probe.y * 1.9 - time * 0.70 + sin(probe.x * 1.1 + time * 0.50) * 1.6);
    value += sin((probe.x + probe.y) * 1.1 + time * 0.45) * 0.6;
    value = value * 0.22 + 0.5;
    return pow(saturate(value), 3.0);
}

float BubbleField(float2 uv, float aspect, float time)
{
    float total = 0.0;
    for (int index = 0; index < BUBBLE_COUNT; index++)
    {
        float seed = float(index);
        float speed = 0.045 + frac(seed * 0.3730) * 0.055;
        float column = frac(seed * 0.2710 + 0.13);
        float radius = 0.0030 + frac(seed * 0.5310) * 0.0038;
        float rise = frac(1.0 - (time * speed + seed * 0.6310));

        float2 delta;
        delta.x = (uv.x - column) * aspect + sin(time * 1.8 + seed * 2.1) * 0.006;
        delta.y = uv.y - rise;

        float shell = smoothstep(radius, radius * 0.30, length(delta));
        float fade = smoothstep(0.0, 0.25, rise) * smoothstep(1.0, 0.75, rise);
        total += shell * fade;
    }
    return saturate(total);
}

float KeyMatch(float3 colour)
{
    return 1.0 - smoothstep(ERASE_TOLERANCE * 0.6, ERASE_TOLERANCE, distance(colour, ERASE_KEY));
}

float4 main(float4 position : SV_POSITION, float2 texture_coordinate : TEXCOORD) : SV_TARGET
{
    float2 uv = texture_coordinate;
    float aspect = Resolution.x / max(Resolution.y, 1.0);

    float4 terminal = shaderTexture.Sample(samplerState, uv);

    float matched = KeyMatch(terminal.rgb);
    if (matched > 0.001)
    {
        float lift = CLONE_DISTANCE / max(Resolution.y, 1.0);
        float4 above = shaderTexture.Sample(samplerState, float2(uv.x, saturate(uv.y - lift)));
        float4 below = shaderTexture.Sample(samplerState, float2(uv.x, saturate(uv.y + lift)));
        float4 clone = above;
        if (KeyMatch(above.rgb) > 0.001)
        {
            clone = below;
        }
        terminal.a = lerp(terminal.a, clone.a, matched);
        terminal.rgb = lerp(terminal.rgb, float3(0.0, 0.0, 0.0), matched);
    }

    float2 causticProbe = float2(uv.x * aspect, uv.y) * CAUSTIC_SCALE;
    float caustics = CausticField(causticProbe, Time);

    float shafts = pow(saturate(1.0 - uv.y), 2.2)
                 * (0.45 + 0.55 * sin(uv.x * 8.0 + Time * 0.30))
                 * (0.55 + 0.45 * sin(uv.x * 3.0 - Time * 0.17));

    float3 shallow = float3(0.06, 0.44, 0.54);
    float3 deep = float3(0.01, 0.08, 0.19);
    float3 water = lerp(shallow, deep, saturate(uv.y * 1.15));

    water += caustics * float3(0.10, 0.30, 0.32);
    water += saturate(shafts) * float3(0.05, 0.15, 0.17);
    water += BubbleField(uv, aspect, Time) * float3(0.40, 0.62, 0.68);

    float fromBackground = distance(terminal.rgb, Background.rgb);
    float luminance = dot(terminal.rgb, float3(0.299, 0.587, 0.114));
    float isContent = max(smoothstep(0.012, 0.055, fromBackground),
                          smoothstep(0.05, 0.20, luminance));

    float3 composited = lerp(water, terminal.rgb, isContent);
    composited = lerp(composited, composited * float3(0.88, 1.02, 1.06), 0.30);

    float alpha = max(terminal.a, isContent);
    return float4(composited, alpha);
}
