#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// GPU twin of ChartRenderer.observationSky (ObservationSkyBackground.swift), which
// still renders the widget's cached dome. Keep the projection, atmosphere stops
// and edge fade in step with the Swift implementation.

// Parameter layout, written by ObservationSkyShaderParameters.
enum Parameter {
    kWidth, kHeight, kScale, kOriginY, kPitch,
    kRightX, kRightY, kFrontX, kFrontY,
    kEastX, kEastY, kEastZ, kNorthX, kNorthY, kNorthZ, kZenithX, kZenithY, kZenithZ,
    kSunPointX, kSunPointY, kDaylight, kTwilight, kPresence,
    kBleed, kExtendsUpward, kPeak
};

static float smoothRange(float low, float high, float value) {
    float t = clamp((value - low) / (high - low), 0.0, 1.0);
    return t * t * (3 - 2 * t);
}

// Premultiplied source-over.
static float3 over(float3 color, float4 layer) {
    return layer.rgb + color * (1 - layer.a);
}

static float4 premultiplied(float3 color, float alpha) {
    return float4(color * alpha, alpha);
}

// Same stops as SkyChartAtmosphere / ChartAtmosphere; piecewise-linear in
// premultiplied color like SwiftUI gradients.
static float4 zenithLayer(float r, float daylight, float presence) {
    float4 a = premultiplied(float3(0.025, 0.12, 0.34), presence * 0.9);
    float4 b = premultiplied(float3(0.055, 0.30, 0.68), daylight * 0.96);
    float4 c = premultiplied(float3(0.27, 0.59, 0.88), daylight);
    if (r <= 0.65) return mix(a, b, max(r, 0.0) / 0.65);
    return mix(b, c, min((r - 0.65) / 0.35, 1.0));
}

static float4 violetLayer(float r, float twilight) {
    float4 a = premultiplied(float3(0.27, 0.16, 0.65), twilight * 0.35);
    float4 b = premultiplied(float3(0.65, 0.27, 0.78), twilight * 0.8);
    float4 c = premultiplied(float3(0.82, 0.40, 0.74), twilight * 0.85);
    if (r <= 0.48) return float4(0);
    if (r <= 0.76) return mix(float4(0), a, (r - 0.48) / 0.28);
    if (r <= 0.94) return mix(a, b, (r - 0.76) / 0.18);
    return mix(b, c, min((r - 0.94) / 0.06, 1.0));
}

static float4 aureoleLayer(float t, float3 color, float strength) {
    if (t <= 0.24) return mix(premultiplied(color, strength), premultiplied(color, strength * 0.48), t / 0.24);
    if (t <= 0.6) return mix(premultiplied(color, strength * 0.48), premultiplied(color, strength * 0.12), (t - 0.24) / 0.36);
    return mix(premultiplied(color, strength * 0.12), float4(0), min((t - 0.6) / 0.4, 1.0));
}

// The round chart's azimuthal-equidistant position, horizon at radius 1.
static float2 chartPoint(float azimuth, float elevationDegrees) {
    return float2(sin(azimuth), cos(azimuth)) * ((90 - elevationDegrees) / 90);
}

static float3 atmosphere(float3 ray, device const float *p) {
    float elevation = asin(clamp(ray.z, -1.0, 1.0)) * 180 / M_PI_F;
    float2 point = chartPoint(atan2(ray.x, ray.y), elevation);
    float daylight = p[kDaylight], twilight = p[kTwilight], presence = p[kPresence];
    float3 color = float3(0.010, 0.020, 0.062);
    color = over(color, premultiplied(float3(0.015, 0.025, 0.075), presence));
    float r = length(point);
    color = over(color, zenithLayer(r, daylight, presence));
    color = over(color, violetLayer(r, twilight));
    float d = distance(point, float2(p[kSunPointX], p[kSunPointY]));
    color = over(color, aureoleLayer(d / 1.1, float3(1, 0.38, 0.20), twilight * 0.88));
    color = over(color, aureoleLayer(d / 0.6, float3(1, 0.72, 0.40), twilight * 0.65));
    return color;
}

// The CPU path pre-blurs the galaxy with a 5-texel box; do the same at sample time.
static float3 galaxy(float3 ray, device const float *p, texture2d<half> texture) {
    constexpr sampler s(address::repeat, filter::linear);
    float3 east = float3(p[kEastX], p[kEastY], p[kEastZ]);
    float3 north = float3(p[kNorthX], p[kNorthY], p[kNorthZ]);
    float3 zenith = float3(p[kZenithX], p[kZenithY], p[kZenithZ]);
    float3 e = east * ray.x + north * ray.y + zenith * ray.z;
    // ICRS → Galactic, as MilkyWayBackground.galactic.
    float3 g = float3(dot(e, float3(-0.0548755604162154, -0.8734370902348850, -0.4838350155487132)),
                      dot(e, float3(0.4941094278755837, -0.4448296299600112, 0.7469822444972189)),
                      dot(e, float3(-0.8676661490190047, -0.1980763734312015, 0.4559837761750669)));
    float2 uv = float2(0.5 - atan2(g.y, g.x) / (2 * M_PI_F), 0.5 - asin(clamp(g.z, -1.0, 1.0)) / M_PI_F);
    float2 texel = 1.0 / float2(texture.get_width(), texture.get_height());
    float3 sum = 0;
    for (int dy = -2; dy <= 2; dy++) {
        float v = clamp(uv.y + dy * texel.y, texel.y * 0.5, 1 - texel.y * 0.5);
        for (int dx = -2; dx <= 2; dx++) {
            sum += float3(texture.sample(s, float2(uv.x + dx * texel.x, v)).rgb);
        }
    }
    return sum / 25;
}

[[ stitchable ]] half4 observationSky(float2 position, half4 current,
                                      device const float *p, int count,
                                      device const float *boundary, int boundaryCount,
                                      texture2d<half> galaxyTexture) {
    float width = p[kWidth], height = p[kHeight];
    // Screen point → local direction (east, north, zenith); ObservationSkyProjection.direction(at:).
    float x = (position.x - width / 2) / p[kScale], y = (p[kOriginY] - position.y) / p[kScale];
    float denominator = 1 + x * x + y * y;
    float r = 2 * x / denominator, u = 2 * y / denominator, f = (1 - x * x - y * y) / denominator;
    float pitch = p[kPitch];
    float depth = f * cos(pitch) - u * sin(pitch);
    float2 right = float2(p[kRightX], p[kRightY]), front = float2(p[kFrontX], p[kFrontY]);
    float2 horizontal = right * r + front * depth;
    float3 ray = float3(horizontal, f * sin(pitch) + u * cos(pitch));
    float facing = dot(ray.xy, front);
    if (ray.z <= 0 || facing < 0) return half4(0);

    float daylight = p[kDaylight];
    float3 color = min(float3(1), atmosphere(ray, p) + galaxy(ray, p, galaxyTexture) * (0.65 * (1 - daylight)));

    // ObservationSkyProjection.edgeFade(at:).
    int column = clamp(int(position.x), 0, boundaryCount - 1);
    float bleed = p[kBleed];
    float vertical = smoothRange(-bleed, bleed, position.y - boundary[column]);
    if (p[kExtendsUpward] > 0.5) vertical = max(vertical, smoothRange(0, p[kPeak], position.y));
    float edge = vertical
        * smoothRange(0, width * 0.08, min(position.x, width - position.x))
        * smoothRange(0, height * 0.08, height - position.y);
    float alpha = edge * smoothRange(0, 0.02, ray.z) * smoothRange(0, 0.05, facing);
    return half4(half3(color * alpha), half(alpha));
}
