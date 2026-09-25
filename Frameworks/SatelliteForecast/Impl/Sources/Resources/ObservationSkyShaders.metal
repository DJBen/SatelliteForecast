#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// Inverse of ObservationSkyProjection. Reprojects the app's composited sky,
// including its atmosphere and Milky Way. Point-source stars and planetary
// disks are positioned separately with the matching forward projection.
[[ stitchable ]] half4 observationSkyDome(float2 position, SwiftUI::Layer layer,
                                         float4 viewport, float4 axes, float4 geometry) {
    float width = viewport.x, height = viewport.y;
    float extent = viewport.z, horizonDepth = viewport.w;
    float baseline = geometry.x, verticalScale = geometry.y;
    float tilt = geometry.z, halfWidth = geometry.w;
    if (position.y > height || position.y < 0) return half4(0);
    float x = (position.x - width * 0.5) / halfWidth * extent;
    float y = (baseline - position.y) / verticalScale - sin(tilt) * horizonDepth;
    float radius2 = x * x + y * y;
    if (radius2 >= 1) return half4(0);
    float cameraDepth = sqrt(1 - radius2);
    float z = y * cos(tilt) + cameraDepth * sin(tilt);
    if (z <= 0) return half4(0);
    float depth = -y * sin(tilt) + cameraDepth * cos(tilt);
    float2 horizontal = axes.xy * x + axes.zw * depth;
    float elevation = asin(clamp(z, 0.0f, 1.0f));
    float distance = (1 - elevation / M_PI_2_F) * width * 0.5;
    float2 source = float2(width * 0.5) - horizontal / max(0.00001f, length(horizontal)) * distance;
    half4 sky = layer.sample(source);
    // No circular chart rim: soften the sky into the card, retaining a separately
    // drawn dotted horizon. Fade before the source texture's horizon ring.
    float edge = 1 - smoothstep(0.92f, 1.0f, radius2);
    float horizon = smoothstep(0.0f, 0.025f, z);
    float sides = smoothstep(0.0f, 14.0f, min(position.x, width - position.x));
    float top = smoothstep(0.0f, 18.0f, position.y);
    return sky * half(edge * horizon * sides * top);
}
