// Kugelbahn background for Windows Terminal, applied via experimental.pixelShaderPath.
//
// The window is a workshop wall with a wooden spiral marble tower in front of it:
// a central post, four corner rods and a base plank, with ramps that wind round
// the post as a square helix seen from the front. Front ramps fall to the left,
// back ramps fall to the right behind the post, and short side ramps carry the
// marble round each corner, so the run reads as going round the post rather
// than bouncing between two walls. At the back left corner the marble tips off
// the side ramp and drops a step onto the back ramp, so it never rolls behind a
// nearer ramp. Three red marbles drop one by one out of a hopper at the top,
// roll down two turns of the helix, leave along an exit ramp and fall down a
// chute on the far left. Everything moves from Time alone.
//
// Every marble rests tangent on the drawn top edge of its ramp: the marble is a
// circle in pixel space, so its centre sits MARBLE_RADIUS * sqrt(1 + slope^2)
// above the edge, with the slope measured in pixels. Both edges are a single
// pixel wide, so tangency is what is seen. A marble shrinks and darkens as it
// goes round the back, and is drawn behind the post and every nearer ramp.
//
// This background is DECORATIVE. A pixel shader receives only Time, Scale,
// Resolution and Background; it cannot read a file, so it cannot know how many
// subagents have finished, nor where the status line draws its jar. The exact
// count lives in the kugelbahn status line's jar below the input field, and this
// file is never rewritten to carry it. The chute ends in the bottom rows on the
// left, where that jar is drawn: the terminal's own glyphs cover the scene, so
// a marble falling down the chute disappears behind the jar instead of fading.
//
// The terminal is sampled strictly on-grid: any offset resampling would smear
// the status line's block art and shear its rows by different amounts. Pixels
// matching the sentinel magenta are replaced by a clone of the terminal a couple
// of rows away, which erases the Claude Code input border and message background
// bars without leaving an opaque streak on a translucent window.

Texture2D shaderTexture;
SamplerState samplerState;

cbuffer PixelShaderSettings
{
    float  Time;
    float  Scale;
    float2 Resolution;
    float4 Background;
};

static const int   TURN_COUNT = 2;
static const int   SEGMENT_COUNT = TURN_COUNT * 4 + 1;
static const int   MARBLE_COUNT = 3;
static const float TOWER_CENTRE = 0.36;
static const float TOWER_HALF_WIDTH = 0.11;
static const float TOWER_DEPTH = -0.09;
static const float RUN_TOP = 0.10;
static const float RAMP_SLOPE = 0.4433;
static const float EXIT_SLOPE = 0.3456;
static const float SIDE_DROP = 0.012;
static const float HAIRPIN_DROP = 0.042;
static const float BOARD_THICKNESS = 0.018;
static const float BACK_THICKNESS = 0.013;
static const float BACK_SHADE = 0.62;
static const float POST_WIDTH = 0.009;
static const float ROD_WIDTH = 0.0025;
static const float BASE_Y = 0.77;
static const float CHUTE_X = 0.044;
static const float CHUTE_END = 0.90;
static const float CHUTE_FLOOR = 0.935;
static const float HOPPER_RIM = 0.03;
static const float MARBLE_RADIUS = 0.0135;
static const float DEPTH_SHRINK = 0.12;
static const float DEPTH_DIM = 0.38;
static const float HOPPER_SECONDS = 0.55;
static const float RAMP_SECONDS = 2.6;
static const float SIDE_SECONDS = 0.7;
static const float EXIT_SECONDS = 3.2;
static const float PIVOT_SECONDS = 0.2;
static const float HAIRPIN_SECONDS = 0.2;
static const float FALL_SECONDS = 0.5;
static const float TURN_SECONDS = 2.0 * (RAMP_SECONDS + SIDE_SECONDS) + PIVOT_SECONDS + HAIRPIN_SECONDS;
static const float ENTRY_SPEED = 0.3;
static const float PI = 3.14159265;

static const float3 ERASE_KEY = float3(1.0, 0.0, 1.0);
static const float  ERASE_TOLERANCE = 0.15;
static const float  CLONE_DISTANCE = 26.0;

float Cover(float signedDistance, float pixelSize)
{
    return saturate(signedDistance / pixelSize + 0.5);
}

float CornerX(float corner)
{
    float side = (corner < 0.5 || corner > 2.5) ? 1.0 : -1.0;
    float depth = (corner > 1.5) ? TOWER_DEPTH : 0.0;
    return TOWER_CENTRE + side * TOWER_HALF_WIDTH + depth;
}

float CornerDepth(float corner)
{
    return (corner > 1.5) ? 1.0 : 0.0;
}

void Segment(float index, float aspect, out float2 rampStart, out float2 rampEnd, out float2 rampDepth)
{
    float rampDrop = 2.0 * TOWER_HALF_WIDTH * RAMP_SLOPE;
    float rampsBefore = floor((index + 1.0) * 0.5);
    float sidesBefore = floor(index * 0.5);
    float hairpinsBefore = floor((index + 2.0) * 0.25);
    float startY = RUN_TOP + rampsBefore * rampDrop + sidesBefore * SIDE_DROP + hairpinsBefore * HAIRPIN_DROP;
    float corner = index - 4.0 * floor(index * 0.25);
    float nextCorner = corner + 1.0 - 4.0 * floor((corner + 1.0) * 0.25);
    rampStart = float2(CornerX(corner), startY);
    if (index > float(SEGMENT_COUNT) - 1.5)
    {
        float endX = CHUTE_X + MARBLE_RADIUS / aspect;
        rampEnd = float2(endX, startY + (rampStart.x - endX) * EXIT_SLOPE);
        rampDepth = float2(0.0, 0.0);
    }
    else
    {
        bool isRamp = frac(index * 0.5) < 0.25;
        rampEnd = float2(CornerX(nextCorner), startY + (isRamp ? rampDrop : SIDE_DROP));
        rampDepth = float2(CornerDepth(corner), CornerDepth(nextCorner));
    }
}

float SurfaceY(float2 rampStart, float2 rampEnd, float positionX)
{
    return rampStart.y + (positionX - rampStart.x) * (rampEnd.y - rampStart.y) / (rampEnd.x - rampStart.x);
}

float PixelSlope(float2 rampStart, float2 rampEnd, float aspect)
{
    return (rampEnd.y - rampStart.y) / (rampEnd.x - rampStart.x) / aspect;
}

float RestOffset(float2 rampStart, float2 rampEnd, float aspect, float radius)
{
    float pixelSlope = PixelSlope(rampStart, rampEnd, aspect);
    return radius * sqrt(1.0 + pixelSlope * pixelSlope);
}

float MarbleRadius(float depth)
{
    return MARBLE_RADIUS * (1.0 - DEPTH_SHRINK * depth);
}

float3 WoodTone(float2 uvCoord, float shade)
{
    float grain = sin(uvCoord.x * 173.0 + uvCoord.y * 11.0) * 0.5
                + sin(uvCoord.x * 47.0 - uvCoord.y * 3.0) * 0.5;
    float3 base = float3(0.46, 0.30, 0.15);
    return base * saturate(shade + grain * 0.07);
}

float3 WallTone(float2 uvCoord)
{
    float plank = sin(uvCoord.x * 26.0) * 0.5 + 0.5;
    float wash = saturate(1.0 - uvCoord.y * 0.55);
    float3 base = float3(0.055, 0.040, 0.030);
    return base * (0.55 + wash * 0.75) + float3(0.012, 0.008, 0.004) * plank;
}

float3 DrawBoard(float3 scene, float2 uvCoord, float2 rampStart, float2 rampEnd, float2 rampDepth,
                 float overhangLeft, float overhangRight, float2 pixel)
{
    float left = min(rampStart.x, rampEnd.x) - overhangLeft;
    float right = max(rampStart.x, rampEnd.x) + overhangRight;
    float along = saturate((uvCoord.x - rampStart.x) / (rampEnd.x - rampStart.x));
    float depth = lerp(rampDepth.x, rampDepth.y, along);
    float thickness = lerp(BOARD_THICKNESS, BACK_THICKNESS, depth);
    float dim = lerp(1.0, BACK_SHADE, depth);
    float below = uvCoord.y - SurfaceY(rampStart, rampEnd, uvCoord.x);
    float mask = Cover(below, pixel.y) * Cover(thickness - below, pixel.y)
               * Cover(uvCoord.x - left, pixel.x) * Cover(right - uvCoord.x, pixel.x);
    float3 wood = WoodTone(float2(uvCoord.x, below * 6.0), (1.0 - saturate(below / thickness) * 0.45) * dim);
    wood = lerp(wood, float3(0.72, 0.52, 0.30) * dim, saturate(1.0 - below / (2.0 * pixel.y)));
    wood = lerp(wood, float3(0.16, 0.10, 0.05) * dim, saturate(1.0 - (thickness - below) / (1.5 * pixel.y)));
    return lerp(scene, wood, mask);
}

float3 DrawRod(float3 scene, float2 uvCoord, float rodX, float rodTop, float shade, float2 pixel)
{
    float mask = Cover(ROD_WIDTH - abs(uvCoord.x - rodX), pixel.x)
               * Cover(uvCoord.y - rodTop, pixel.y) * Cover(BASE_Y - uvCoord.y, pixel.y);
    return lerp(scene, WoodTone(uvCoord, shade), mask);
}

float3 DrawMarble(float3 scene, float2 uvCoord, float aspect, float2 centre, float radius, float dim,
                  float spin, float pixelY)
{
    float2 toCentre = float2((uvCoord.x - centre.x) * aspect, uvCoord.y - centre.y);
    float distanceToCentre = length(toCentre);
    float shell = Cover(radius - distanceToCentre, pixelY);
    float highlight = saturate(0.5 - (toCentre.x + toCentre.y) / (radius * 2.4));
    float3 plastic = lerp(float3(0.52, 0.055, 0.075), float3(1.0, 0.56, 0.48), highlight * highlight);
    float seam = abs(dot(toCentre, float2(-sin(spin), cos(spin))));
    float rim = saturate(distanceToCentre / radius);
    float rimFourth = rim * rim * rim * rim;
    plastic *= (1.0 - 0.2 * saturate(1.0 - seam / (radius * 0.18))) * (1.0 - 0.35 * rimFourth) * dim;
    return lerp(scene, plastic, shell);
}

void HopperPoints(float aspect, out float2 landing, out float outletY)
{
    float2 rampStart;
    float2 rampEnd;
    float2 rampDepth;
    Segment(0.0, aspect, rampStart, rampEnd, rampDepth);
    landing.x = rampStart.x - 1.6 * MARBLE_RADIUS / aspect;
    landing.y = SurfaceY(rampStart, rampEnd, landing.x) - RestOffset(rampStart, rampEnd, aspect, MARBLE_RADIUS);
    outletY = landing.y - MARBLE_RADIUS - 0.004;
}

void RollOn(float index, float startX, float endX, float rollT, float aspect, out float2 centre, out float depth)
{
    float2 rampStart;
    float2 rampEnd;
    float2 rampDepth;
    Segment(index, aspect, rampStart, rampEnd, rampDepth);
    float amount = rollT * (ENTRY_SPEED + (1.0 - ENTRY_SPEED) * rollT);
    centre.x = lerp(startX, endX, amount);
    depth = lerp(rampDepth.x, rampDepth.y, saturate((centre.x - rampStart.x) / (rampEnd.x - rampStart.x)));
    centre.y = SurfaceY(rampStart, rampEnd, centre.x) - RestOffset(rampStart, rampEnd, aspect, MarbleRadius(depth));
}

void MarbleState(int marbleIndex, float aspect, out float2 centre, out float depth, out float layer)
{
    float runSeconds = float(TURN_COUNT) * TURN_SECONDS;
    float cycleSeconds = HOPPER_SECONDS + runSeconds + EXIT_SECONDS + PIVOT_SECONDS + FALL_SECONDS;
    float clock = frac((Time + float(marbleIndex) * cycleSeconds / float(MARBLE_COUNT)) / cycleSeconds) * cycleSeconds;
    float2 landing;
    float outletY;
    HopperPoints(aspect, landing, outletY);
    float2 rampStart;
    float2 rampEnd;
    float2 rampDepth;
    depth = 0.0;
    layer = 2.0;

    if (clock < HOPPER_SECONDS)
    {
        float fallT = clock / HOPPER_SECONDS;
        centre = float2(landing.x, lerp(HOPPER_RIM + MARBLE_RADIUS + 0.003, landing.y, fallT * fallT));
        return;
    }
    clock -= HOPPER_SECONDS;

    if (clock < runSeconds)
    {
        float turn = floor(clock / TURN_SECONDS);
        float phase = clock - turn * TURN_SECONDS;
        float index = turn * 4.0;
        Segment(index + 1.0, aspect, rampStart, rampEnd, rampDepth);
        float2 hairpin = rampEnd;
        float hairpinAngle = atan2(-1.0, PixelSlope(rampStart, rampEnd, aspect));
        float2 hairpinOffset = float2(MarbleRadius(1.0) / aspect, MarbleRadius(1.0));
        float dropX = hairpin.x - hairpinOffset.x;

        if (phase < RAMP_SECONDS)
        {
            RollOn(index, (turn < 0.5) ? landing.x : CornerX(0.0), CornerX(1.0), phase / RAMP_SECONDS, aspect, centre, depth);
            return;
        }
        phase -= RAMP_SECONDS;
        layer = 1.0;
        if (phase < SIDE_SECONDS)
        {
            RollOn(index + 1.0, CornerX(1.0), hairpin.x + cos(hairpinAngle) * hairpinOffset.x,
                   phase / SIDE_SECONDS, aspect, centre, depth);
            return;
        }
        phase -= SIDE_SECONDS;
        depth = 1.0;
        if (phase < PIVOT_SECONDS)
        {
            float pivotT = phase / PIVOT_SECONDS;
            float angle = lerp(hairpinAngle, -PI, pivotT * pivotT);
            centre = hairpin + float2(cos(angle), sin(angle)) * hairpinOffset;
            return;
        }
        phase -= PIVOT_SECONDS;
        layer = 0.0;
        Segment(index + 2.0, aspect, rampStart, rampEnd, rampDepth);
        if (phase < HAIRPIN_SECONDS)
        {
            float dropT = phase / HAIRPIN_SECONDS;
            float landingY = SurfaceY(rampStart, rampEnd, dropX) - RestOffset(rampStart, rampEnd, aspect, MarbleRadius(1.0));
            centre = float2(dropX, lerp(hairpin.y, landingY, dropT * dropT));
            return;
        }
        phase -= HAIRPIN_SECONDS;
        if (phase < RAMP_SECONDS)
        {
            RollOn(index + 2.0, dropX, CornerX(3.0), phase / RAMP_SECONDS, aspect, centre, depth);
            return;
        }
        phase -= RAMP_SECONDS;
        layer = 1.0;
        RollOn(index + 3.0, CornerX(3.0), CornerX(0.0), saturate(phase / SIDE_SECONDS), aspect, centre, depth);
        return;
    }
    clock -= runSeconds;

    Segment(float(SEGMENT_COUNT) - 1.0, aspect, rampStart, rampEnd, rampDepth);
    float tipAngle = atan2(-1.0, PixelSlope(rampStart, rampEnd, aspect));
    float2 tipOffset = float2(MARBLE_RADIUS / aspect, MARBLE_RADIUS);

    if (clock < EXIT_SECONDS)
    {
        RollOn(float(SEGMENT_COUNT) - 1.0, rampStart.x, rampEnd.x + cos(tipAngle) * tipOffset.x,
               clock / EXIT_SECONDS, aspect, centre, depth);
        return;
    }
    clock -= EXIT_SECONDS;

    if (clock < PIVOT_SECONDS)
    {
        float pivotT = clock / PIVOT_SECONDS;
        float angle = lerp(tipAngle, -PI, pivotT * pivotT);
        centre = rampEnd + float2(cos(angle), sin(angle)) * tipOffset;
        return;
    }
    clock -= PIVOT_SECONDS;

    float fallT = saturate(clock / FALL_SECONDS);
    centre = float2(CHUTE_X, lerp(rampEnd.y, CHUTE_FLOOR, fallT * fallT));
}

float3 DrawMarbleLayer(float3 scene, float2 uvCoord, float aspect, float wantedLayer, float pixelY)
{
    for (int marbleIndex = 0; marbleIndex < MARBLE_COUNT; marbleIndex++)
    {
        float2 centre;
        float depth;
        float layer;
        MarbleState(marbleIndex, aspect, centre, depth, layer);
        if (abs(layer - wantedLayer) < 0.5)
        {
            float radius = MarbleRadius(depth);
            float spin = centre.x * aspect / radius;
            scene = DrawMarble(scene, uvCoord, aspect, centre, radius, 1.0 - DEPTH_DIM * depth, spin, pixelY);
        }
    }
    return scene;
}

float3 DrawHopper(float3 scene, float2 uvCoord, float aspect, float2 pixel)
{
    float2 landing;
    float outletY;
    HopperPoints(aspect, landing, outletY);
    for (int pileIndex = -1; pileIndex <= 1; pileIndex++)
    {
        float2 pileCentre = float2(landing.x + float(pileIndex) * 0.016, HOPPER_RIM + 0.002);
        scene = DrawMarble(scene, uvCoord, aspect, pileCentre, MARBLE_RADIUS, 1.0, 0.0, pixel.y);
    }
    float funnelT = saturate((uvCoord.y - HOPPER_RIM) / (outletY - HOPPER_RIM));
    float funnelHalf = lerp(0.045, MARBLE_RADIUS / aspect + 0.005, funnelT);
    float mask = Cover(funnelHalf - abs(uvCoord.x - landing.x), pixel.x)
               * Cover(uvCoord.y - HOPPER_RIM, pixel.y) * Cover(outletY - uvCoord.y, pixel.y);
    float3 wood = WoodTone(float2(uvCoord.x, uvCoord.y * 4.0), 0.80 - 0.25 * funnelT);
    wood = lerp(wood, float3(0.72, 0.52, 0.30), saturate(1.0 - (uvCoord.y - HOPPER_RIM) / (2.0 * pixel.y)));
    return lerp(scene, wood, mask);
}

float4 main(float4 position : SV_POSITION, float2 texture_coordinate : TEXCOORD) : SV_TARGET
{
    float2 uvCoord = texture_coordinate;
    float aspect = Resolution.x / max(Resolution.y, 1.0);
    float2 pixel = 1.0 / max(Resolution, float2(1.0, 1.0));

    float4 terminal = shaderTexture.Sample(samplerState, uvCoord);

    float matched = 1.0 - smoothstep(ERASE_TOLERANCE * 0.6, ERASE_TOLERANCE,
                                     distance(terminal.rgb, ERASE_KEY));
    if (matched > 0.001)
    {
        float lift = CLONE_DISTANCE / max(Resolution.y, 1.0);
        float4 above = shaderTexture.Sample(samplerState, float2(uvCoord.x, saturate(uvCoord.y - lift)));
        float4 below = shaderTexture.Sample(samplerState, float2(uvCoord.x, saturate(uvCoord.y + lift)));
        float4 clone = above;
        float aboveMatched = 1.0 - smoothstep(ERASE_TOLERANCE * 0.6, ERASE_TOLERANCE,
                                              distance(above.rgb, ERASE_KEY));
        if (aboveMatched > 0.001)
        {
            clone = below;
        }
        terminal.a = lerp(terminal.a, clone.a, matched);
        terminal.rgb = lerp(terminal.rgb, float3(0.0, 0.0, 0.0), matched);
    }

    float3 scene = WallTone(uvCoord);
    float halfWidth = MARBLE_RADIUS / aspect;
    float overhang = halfWidth + 0.004;
    float2 rampStart;
    float2 rampEnd;
    float2 rampDepth;

    Segment(float(SEGMENT_COUNT) - 1.0, aspect, rampStart, rampEnd, rampDepth);
    float2 exitEnd = rampEnd;
    float chuteLeft = CHUTE_X - halfWidth - 0.003;
    float chuteRight = CHUTE_X + halfWidth;
    float plate = Cover(uvCoord.x - chuteLeft, pixel.x) * Cover(chuteRight - uvCoord.x, pixel.x)
                * Cover(uvCoord.y - (exitEnd.y - 0.04), pixel.y) * Cover(CHUTE_END - uvCoord.y, pixel.y);
    scene = lerp(scene, float3(0.10, 0.065, 0.035), plate);

    float rodTop = RUN_TOP - 0.03;
    scene = DrawRod(scene, uvCoord, CornerX(2.0) - 0.006, rodTop, 0.30, pixel);
    scene = DrawRod(scene, uvCoord, CornerX(3.0) + 0.006, rodTop, 0.30, pixel);

    for (int backIndex = 0; backIndex < SEGMENT_COUNT; backIndex++)
    {
        Segment(float(backIndex), aspect, rampStart, rampEnd, rampDepth);
        if (rampDepth.x > 0.5 && rampDepth.y > 0.5)
        {
            scene = DrawBoard(scene, uvCoord, rampStart, rampEnd, rampDepth, overhang, overhang, pixel);
        }
    }
    scene = DrawMarbleLayer(scene, uvCoord, aspect, 0.0, pixel.y);

    scene = DrawRod(scene, uvCoord, CornerX(1.0) - 0.006, rodTop, 0.55, pixel);
    scene = DrawRod(scene, uvCoord, CornerX(0.0) + 0.006, rodTop, 0.55, pixel);
    float postX = TOWER_CENTRE + TOWER_DEPTH * 0.5;
    float across = saturate(abs(uvCoord.x - postX) / POST_WIDTH);
    float postMask = Cover(POST_WIDTH - abs(uvCoord.x - postX), pixel.x)
                   * Cover(uvCoord.y - 0.05, pixel.y) * Cover(BASE_Y - uvCoord.y, pixel.y);
    float3 postWood = WoodTone(float2(uvCoord.x * 0.2, uvCoord.y * 3.0), 0.35 + 0.45 * sqrt(1.0 - across * across));
    scene = lerp(scene, postWood, postMask);

    for (int sideIndex = 0; sideIndex < SEGMENT_COUNT; sideIndex++)
    {
        Segment(float(sideIndex), aspect, rampStart, rampEnd, rampDepth);
        if (abs(rampDepth.x - rampDepth.y) > 0.5)
        {
            scene = DrawBoard(scene, uvCoord, rampStart, rampEnd, rampDepth, 0.0, 0.0, pixel);
        }
    }
    scene = DrawMarbleLayer(scene, uvCoord, aspect, 1.0, pixel.y);

    float baseLeft = CornerX(2.0) - 0.012;
    float baseRight = CornerX(0.0) + 0.012;
    float baseDepth = saturate((uvCoord.y - BASE_Y) / 0.014);
    float baseMask = Cover(uvCoord.x - baseLeft, pixel.x) * Cover(baseRight - uvCoord.x, pixel.x)
                   * Cover(uvCoord.y - BASE_Y, pixel.y) * Cover(BASE_Y + 0.014 - uvCoord.y, pixel.y);
    float3 baseWood = WoodTone(float2(uvCoord.x, uvCoord.y * 6.0), 0.78 - 0.3 * baseDepth);
    baseWood = lerp(baseWood, float3(0.72, 0.52, 0.30), saturate(1.0 - (uvCoord.y - BASE_Y) / (2.0 * pixel.y)));
    scene = lerp(scene, baseWood, baseMask);

    for (int frontIndex = 0; frontIndex < SEGMENT_COUNT; frontIndex++)
    {
        Segment(float(frontIndex), aspect, rampStart, rampEnd, rampDepth);
        if (rampDepth.x < 0.5 && rampDepth.y < 0.5)
        {
            bool isExit = frontIndex == SEGMENT_COUNT - 1;
            scene = DrawBoard(scene, uvCoord, rampStart, rampEnd, rampDepth, isExit ? 0.0 : overhang, overhang, pixel);
        }
    }

    float leftRail = Cover(0.002 - abs(uvCoord.x - (chuteLeft - 0.002)), pixel.x)
                   * Cover(uvCoord.y - (exitEnd.y - 0.04), pixel.y) * Cover(CHUTE_END - uvCoord.y, pixel.y);
    float rightRail = Cover(0.002 - abs(uvCoord.x - (chuteRight + 0.002)), pixel.x)
                    * Cover(uvCoord.y - (exitEnd.y + BOARD_THICKNESS), pixel.y) * Cover(CHUTE_END - uvCoord.y, pixel.y);
    scene = lerp(scene, WoodTone(uvCoord, 0.62), saturate(leftRail + rightRail));

    scene = DrawMarbleLayer(scene, uvCoord, aspect, 2.0, pixel.y);
    scene = DrawHopper(scene, uvCoord, aspect, pixel);

    float fromBackground = distance(terminal.rgb, Background.rgb);
    float luminance = dot(terminal.rgb, float3(0.299, 0.587, 0.114));
    float isContent = max(smoothstep(0.012, 0.055, fromBackground),
                          smoothstep(0.05, 0.20, luminance));

    float3 composited = lerp(scene, terminal.rgb, isContent);
    float alpha = max(terminal.a, isContent);
    return float4(composited, alpha);
}
