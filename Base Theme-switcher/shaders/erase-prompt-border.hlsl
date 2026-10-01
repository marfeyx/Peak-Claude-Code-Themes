// Neutral border eraser for Windows Terminal.
// Applied via experimental.pixelShaderPath. The Claude Code theme paints
// promptBorder and promptBorderShimmer a sentinel magenta; every pixel matching
// it is replaced by a clone of the terminal a couple of text rows away, so the
// rules above and below the input field take on whatever the surrounding
// background actually is, including its alpha. That matters on a translucent
// window, where painting a colour over them would still leave a solid streak.
//
// If the rules ever show up magenta, the chroma key stopped matching.

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

float KeyMatch(float3 colour)
{
    return 1.0 - smoothstep(ERASE_TOLERANCE * 0.6, ERASE_TOLERANCE, distance(colour, ERASE_KEY));
}

float4 main(float4 position : SV_POSITION, float2 texture_coordinate : TEXCOORD) : SV_TARGET
{
    float2 uv = texture_coordinate;
    float4 terminal = shaderTexture.Sample(samplerState, uv);

    float matched = KeyMatch(terminal.rgb);
    if (matched <= 0.001)
    {
        return terminal;
    }

    float lift = CLONE_DISTANCE / max(Resolution.y, 1.0);

    float4 above = shaderTexture.Sample(samplerState, float2(uv.x, saturate(uv.y - lift)));
    float4 below = shaderTexture.Sample(samplerState, float2(uv.x, saturate(uv.y + lift)));
    float4 farAbove = shaderTexture.Sample(samplerState, float2(uv.x, saturate(uv.y - lift * 2.0)));

    float4 clone = above;
    if (KeyMatch(above.rgb) > 0.001)
    {
        clone = below;
    }
    if (KeyMatch(clone.rgb) > 0.001)
    {
        clone = farAbove;
    }
    float4 replacement = float4(Background.rgb, clone.a);
    return lerp(terminal, replacement, matched);
}
