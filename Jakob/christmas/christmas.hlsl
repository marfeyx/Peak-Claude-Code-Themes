// Christmas snowfall for Windows Terminal, applied via experimental.pixelShaderPath.
//
// The whole window becomes the night outside the statusline's window: a deep
// indigo sky, a warm candle glow low on the left, cold moonlight high on the
// right, and three parallax layers of snow falling across the glass. The
// terminal is sampled on-grid only — any added offset resamples the texture
// off-texel and smears the half-block pixel art the christmas theme draws.
//
// Pixels matching the sentinel magenta are replaced by a clone of the terminal a
// couple of rows away, which erases the Claude Code message backgrounds without
// leaving an opaque streak on a translucent window. Terminal content is detected
// by its distance from the declared background as well as by luminance, so dark
// pixels inside a sprite are not punched through.

Texture2D shaderTexture;
SamplerState samplerState;

cbuffer PixelShaderSettings
{
    float  Time;
    float  Scale;
    float2 Resolution;
    float4 Background;
};

static const float3 ERASE_KEY = float3(1.0, 0.0, 1.0);
static const float  ERASE_TOLERANCE = 0.15;
static const float  CLONE_DISTANCE = 26.0;

static const float3 SKY_HIGH = float3(0.014, 0.032, 0.082);
static const float3 SKY_LOW = float3(0.046, 0.064, 0.126);
static const float3 CANDLE_TINT = float3(0.250, 0.138, 0.044);
static const float3 MOON_TINT = float3(0.095, 0.112, 0.158);
static const float3 FLAKE_TINT = float3(0.760, 0.835, 0.950);

float CellNoise(float2 cellId)
{
    return frac(sin(cellId.x * 127.1 + cellId.y * 311.7) * 43758.5453);
}

// One parallax layer of snow. The cell grid is anchored to the drifting probe,
// so every flake is a pure function of Time and its cell: nothing is random and
// two frames of the same instant match.
float SnowLayer(float2 uv, float aspect, float grain, float fall, float sway,
                float radius, float occupancy, float salt)
{
    float2 probe = float2(uv.x * aspect, uv.y) * grain;
    probe.y -= Time * fall * grain;
    probe.x -= Time * sway * grain;
    probe.x += sin(probe.y * 0.42 + salt) * 0.45;

    float2 cellId = floor(probe);
    float2 offset = frac(probe) - 0.5;

    float jitterX = CellNoise(cellId + salt) - 0.5;
    float jitterY = CellNoise(cellId + salt + 7.31) - 0.5;
    float present = CellNoise(cellId + salt + 31.77);
    float bright = CellNoise(cellId + salt + 19.13);

    float2 delta = offset - float2(jitterX, jitterY) * 0.74;
    float flake = smoothstep(radius, 0.0, length(delta));
    flake *= (present < occupancy) ? 1.0 : 0.0;
    return flake * (0.40 + 0.60 * bright);
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

    float3 night = lerp(SKY_HIGH, SKY_LOW, saturate(uv.y * 1.10));

    float2 candleAt = float2(0.17, 1.03);
    float candle = pow(saturate(1.0 - length((uv - candleAt) * float2(aspect, 1.0)) * 1.05), 3.0);
    night += candle * CANDLE_TINT;

    float2 moonAt = float2(0.87, -0.05);
    float moonlight = pow(saturate(1.0 - length((uv - moonAt) * float2(aspect, 1.0)) * 1.25), 3.0);
    night += moonlight * MOON_TINT;

    float flakes = 0.0;
    flakes += SnowLayer(uv, aspect, 30.0, 0.030, 0.0060, 0.040, 0.18, 0.0) * 0.45;
    flakes += SnowLayer(uv, aspect, 20.0, 0.055, 0.0105, 0.045, 0.16, 11.0) * 0.72;
    flakes += SnowLayer(uv, aspect, 12.0, 0.086, 0.0170, 0.052, 0.14, 23.0) * 1.00;
    night += saturate(flakes) * FLAKE_TINT;

    float drift = pow(saturate(uv.y - 0.86) / 0.14, 2.2);
    night += drift * float3(0.055, 0.068, 0.082);

    float fromBackground = distance(terminal.rgb, Background.rgb);
    float luminance = dot(terminal.rgb, float3(0.299, 0.587, 0.114));
    float isContent = max(smoothstep(0.012, 0.055, fromBackground),
                          smoothstep(0.05, 0.20, luminance));

    float3 composited = lerp(night, terminal.rgb, isContent);
    composited = lerp(composited, composited * float3(1.03, 1.00, 0.97), 0.22);

    float alpha = max(terminal.a, isContent);
    return float4(composited, alpha);
}
