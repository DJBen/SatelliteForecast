#include <metal_stdlib>
using namespace metal;

// Star billboard optics adapted from DJBen/StarryNight Planetarium/Metal/StarShaders.metal.
// MIT copyright (c) 2021 Ben Lu. See PlanetariumCredits.txt.
struct Uniforms {
    float4 right, up, forward;
    float4 north, east, zenith;
    float4 sun; // local direction, elevation
    float4 viewport; // pixels x/y, tan(vertical FOV/2), vertical FOV degrees
    float4 effects; // daylight, twilight, seconds, drawable pixels per point
};
struct StarInstance { float4 positionMagnitude; float4 colorWavelength; };
struct LineVertex { float4 position; float4 color; float4 profile; };
struct Sprite { float4 positionSize; float4 tint; float4 uvRect; float4 options; };
struct Raster { float4 position [[position]]; float2 uv; float4 color; float4 optics; float4 flow; };

// Periodic angular profile, matched by PlanetariumGeometry for hit testing.
float mountainHeight(float a) {
    return 0.006+0.008*abs(sin(a*7+0.6))+0.004*sin(a*13+1.1)
        +0.002*sin(a*29)+0.001*sin(a*61+0.4);
}
bool behindGround(float3 d) {
    return asin(clamp(d.y,-1.0,1.0))<mountainHeight(atan2(d.x,-d.z));
}
float hash21(float2 p) { return fract(sin(dot(p,float2(127.1,311.7)))*43758.5453); }
float noise2(float2 p) {
    float2 i=floor(p), f=fract(p); f=f*f*(3-2*f);
    return mix(mix(hash21(i),hash21(i+float2(1,0)),f.x),
               mix(hash21(i+float2(0,1)),hash21(i+1),f.x),f.y);
}

constant float2 billboardQuad[6] = {float2(-1,-1),float2(1,-1),float2(-1,1),float2(1,-1),float2(1,1),float2(-1,1)};
float3 local(float3 v, constant Uniforms &u) { return float3(dot(v,u.east.xyz),dot(v,u.zenith.xyz),-dot(v,u.north.xyz)); }
float4 project(float3 p, constant Uniforms &u) {
    float z = dot(p,u.forward.xyz);
    return float4(dot(p,u.right.xyz)/(u.viewport.z*u.viewport.x/u.viewport.y),dot(p,u.up.xyz)/u.viewport.z,z-0.001,z);
}
vertex Raster background_vertex(uint id [[vertex_id]]) {
    Raster o; o.position=float4(billboardQuad[id],0.999,1); o.uv=billboardQuad[id]; return o;
}
// A continuous lookup across the two 8K tiles, including longitude wrap.
float3 galaxySample(float2 uv, float lod, texture2d<float> milkyLeft, texture2d<float> milkyRight) {
    constexpr sampler skySampler(address::clamp_to_edge, filter::linear, mip_filter::linear);
    float x=fract(uv.x)*2;
    float3 galaxy=x<1 ? milkyLeft.sample(skySampler,float2(x,uv.y),level(lod)).rgb
                        : milkyRight.sample(skySampler,float2(x-1,uv.y),level(lod)).rgb;
    // Blend the adjoining edge texels, including the 360-degree wrap seam.
    float edge=exp2(lod)*0.5/8192.0;
    if(abs(x-1)<edge) {
        galaxy=mix(milkyLeft.sample(skySampler,float2(1,uv.y),level(lod)).rgb,
                   milkyRight.sample(skySampler,float2(0,uv.y),level(lod)).rgb,
                   smoothstep(1-edge,1+edge,x));
    } else if(x<edge || x>2-edge) {
        float wrapped=x>1 ? x-2 : x;
        galaxy=mix(milkyRight.sample(skySampler,float2(1,uv.y),level(lod)).rgb,
                   milkyLeft.sample(skySampler,float2(0,uv.y),level(lod)).rgb,
                   smoothstep(-edge,edge,wrapped));
    }
    return galaxy;
}
float3 galacticLight(float3 d, constant Uniforms &u,
                     texture2d<float> milkyLeft, texture2d<float> milkyRight) {
    float3 eq=d.x*u.east.xyz+d.y*u.zenith.xyz-d.z*u.north.xyz;
    float3 gal=float3(dot(eq,float3(-0.05487556,-0.87343709,-0.48383502)),dot(eq,float3(0.49410943,-0.44482963,0.74698224)),dot(eq,float3(-0.86766615,-0.19807637,0.45598378)));
    float2 uv=float2(0.5-atan2(gal.y,gal.x)/(2*M_PI_F),0.5-asin(clamp(gal.z,-1.0,1.0))/M_PI_F);
    float2 dx=dfdx(uv), dy=dfdy(uv);
    dx.x-=round(dx.x); dy.x-=round(dy.x);
    float2 tx=dx*float2(16384,8192), ty=dy*float2(16384,8192);
    // Largest singular value of the pixel footprint. Unlike max(|dx|,|dy|),
    // this does not sharpen/soften the mip choice just because the phone rolls.
    float a=dot(tx,tx), b=dot(tx,ty), c=dot(ty,ty);
    float footprint=sqrt(max(0.0,0.5*(a+c+sqrt((a-c)*(a-c)+4*b*b))));
    // Match the mip to the actual pixel footprint; the former negative LOD
    // bias brought unresolved high-frequency grain back into the image.
    float lod=clamp(log2(max(footprint,1.0)),0.0,13.0);
    float3 original=galaxySample(uv,lod,milkyLeft,milkyRight);
    float closeView=1-smoothstep(10.0,32.0,u.viewport.w);
    if(closeView<=0) return original;
    // Separate diffuse galactic structure from the baked-in tiny star speckles.
    // At telescope zoom those speckles otherwise grow into grainy blobs. Work
    // in linear light and retain strong medium-scale dust-lane contrast, while
    // shrinking low-amplitude high-frequency variation toward the diffuse base.
    float3 base=galaxySample(uv,max(lod,5.0),milkyLeft,milkyRight);
    float3 structure=galaxySample(uv,max(lod,3.0),milkyLeft,milkyRight);
    float3 detail=structure-base;
    float signal=max(dot(base,float3(0.2126,0.7152,0.0722)),0.003);
    float keepStructure=smoothstep(0.12,0.40,length(detail)/signal);
    float3 diffuse=max(float3(0),base+detail*keepStructure);
    // This affects only the photographic background. Catalog stars and their
    // optics are rendered separately and remain sharp at every magnification.
    return mix(original,diffuse,closeView);
}

float3 atmosphere(float3 d, constant Uniforms &u) {
    float h=exp(-max(d.y,0.0)*5.0), glow=pow(max(dot(d,u.sun.xyz),0.0),12.0);
    float3 night=mix(float3(0.0015,0.003,0.012),float3(0.018,0.030,0.053),h);
    float3 day=mix(float3(0.025,0.16,0.42),float3(0.37,0.60,0.82),h);
    return mix(night,day,u.effects.x)+u.effects.y*h*float3(0.18,0.06,0.12)
        +glow*u.effects.y*float3(0.65,0.22,0.06);
}
// A bounded directional gravity-wave spectrum. xy is the wave vector (rad/m),
// z is slope amplitude, w is phase. Incommensurate lengths and a spread around
// the prevailing wind avoid a short repeating lattice. No simulation textures.
constant float4 waterWaves[10] = {
    float4(0.31, 0.17, 0.018, 0.4), float4(0.57, -0.26, 0.016, 2.7),
    float4(0.83, 0.61, 0.014, 5.1), float4(1.37, 0.12, 0.013, 1.3),
    float4(1.91, -1.13, 0.011, 4.4), float4(2.79, 1.67, 0.010, 0.9),
    float4(4.31, -0.71, 0.008, 3.8), float4(5.17, 3.93, 0.007, 2.1),
    float4(8.73, -3.11, 0.005, 5.7), float4(11.41, 5.83, 0.004, 1.9)
};
float3 waterSlope(float2 p, float2 pixelX, float2 pixelY, float seconds) {
    float2 slope=0;
    float variance=0;
    for(uint i=0;i<10;i++) {
        float4 wave=waterWaves[i];
        float k=length(wave.xy), omega=sqrt(9.81*k);
        float2 phaseFootprint=float2(dot(wave.xy,pixelX),dot(wave.xy,pixelY));
        // Gaussian pixel-footprint integration fades waves BEFORE Nyquist,
        // including anisotropic grazing footprints and 30 Hz temporal sampling.
        float filter=exp(-0.5*(dot(phaseFootprint,phaseFootprint)+pow(omega/30.0,2.0)));
        slope+=normalize(wave.xy)*wave.z*cos(dot(wave.xy,p)-omega*seconds+wave.w)*filter;
        variance+=0.5*wave.z*wave.z*(1-filter*filter);
    }
    return float3(slope,variance);
}
float filteredBedNoise(float2 p, float footprint) {
    return mix(0.5,noise2(p),1-smoothstep(0.25,1.0,footprint));
}
float3 mountainColor(float azimuth, float altitude, float ridge, float daylight) {
    float backRidge=mountainHeight(azimuth+0.14)*0.72;
    float layer=smoothstep(backRidge-0.002,backRidge+0.002,altitude);
    // Continuous dark shoreline; both the direct and reflected skyline use
    // this material. No directional rock-noise seam at +/- pi.
    float3 mountain=mix(float3(0.006,0.011,0.022),float3(0.018,0.026,0.049),layer);
    return mountain*mix(1.0,4.0,daylight);
}
fragment float4 background_fragment(Raster in [[stage_in]], constant Uniforms &u [[buffer(0)]],
                                    texture2d<float> milkyLeft [[texture(1)]],
                                    texture2d<float> milkyRight [[texture(2)]]) {
    float3 d=normalize(u.forward.xyz+in.uv.x*u.viewport.z*u.viewport.x/u.viewport.y*u.right.xyz+in.uv.y*u.viewport.z*u.up.xyz);
    float a=atan2(d.x,-d.z), altitude=asin(clamp(d.y,-1.0,1.0));
    float ridge=mountainHeight(a);
    // Derivatives are evaluated before any divergent shoreline branch.
    float angularPixel=max(length(dfdx(d)),length(dfdy(d)));
    float depth=max(-d.y,0.0001);
    float2 p=d.xz*(1.6/depth); // eye 1.6 m above a calm water plane
    float2 pixelX=dfdx(p), pixelY=dfdy(p);
    float footprint=max(length(pixelX),length(pixelY));
    if(d.y>=0 && altitude<ridge) {
        return float4(mountainColor(a,altitude,ridge,u.effects.x),1);
    }
    if(d.y<0) {
        float3 spectrum=waterSlope(p,pixelX,pixelY,u.effects.z);
        float3 normal=normalize(float3(-spectrum.x,1,-spectrum.y));
        float3 reflected=reflect(d,normal);
        // Do not clamp reflected.y: below-skyline rays must see the mountain,
        // including troughs where the reflection points below the horizon.
        float reflectedAzimuth=atan2(reflected.x,-reflected.z);
        float reflectedAltitude=asin(clamp(reflected.y,-1.0,1.0));
        float reflectedRidge=mountainHeight(reflectedAzimuth);
        // Unresolved wave energy becomes reflection roughness instead of
        // disappearing or producing sparkling subpixel mountain silhouettes.
        float reflectionWidth=max(angularPixel*1.5,0.002+2*sqrt(spectrum.z));
        float skyCoverage=smoothstep(-reflectionWidth,reflectionWidth,reflectedAltitude-reflectedRidge);
        float3 reflectedSky=atmosphere(reflected,u);
        reflectedSky+=galacticLight(reflected,u,milkyLeft,milkyRight)*(1-u.effects.x)*0.25;
        float3 reflection=mix(mountainColor(reflectedAzimuth,reflectedAltitude,reflectedRidge,u.effects.x),reflectedSky,skyCoverage);
        // Water IOR ~1.333 gives F0 ~0.0204. Grazing views reflect the sky;
        // downward views transmit more light to a subdued shallow bed.
        float fresnel=0.0204+0.9796*pow(1-saturate(dot(-d,normal)),5.0);
        float bed=filteredBedNoise(p*1.7,footprint*1.7)*0.65
            +filteredBedNoise(p*5.9,footprint*5.9)*0.25
            +filteredBedNoise(p*0.43,footprint*0.43)*0.1;
        float3 bedColor=mix(float3(0.004,0.015,0.022),float3(0.013,0.031,0.038),bed);
        float transmission=exp(-0.16/max(-d.y,0.03));
        float3 clearWater=mix(float3(0.003,0.010,0.020),bedColor,transmission)*mix(1.0,3.5,u.effects.x);
        return float4(mix(clearWater,reflection,fresnel),1);
    }
    float3 color=atmosphere(d,u);
    color+=galacticLight(d,u,milkyLeft,milkyRight)*(1-u.effects.x)*smoothstep(0.0,0.15,d.y)*0.48;
    if(u.sun.w>-0.27) {
        float disk=smoothstep(cos(0.275*M_PI_F/180.0),cos(0.26*M_PI_F/180.0),dot(d,u.sun.xyz));
        color+=disk*float3(2.0,1.85,1.5);
    }
    // Solar aureole, diffraction and lens ghosts follow the projected source.
    float facing=dot(u.sun.xyz,u.forward.xyz);
    if(u.sun.w>0 && facing>0) {
        float2 solar=float2(dot(u.sun.xyz,u.right.xyz)/(u.viewport.z*u.viewport.x/u.viewport.y),dot(u.sun.xyz,u.up.xyz)/u.viewport.z)/facing;
        if(all(abs(solar)<1.0)) {
            float2 delta=(in.uv-solar)*float2(u.viewport.x/u.viewport.y,1);
            float r=length(delta);
            color+=float3(1,0.75,0.42)*exp(-r*r*40)*0.5;
            color+=float3(1,0.90,0.7)*exp(-r*r*700)*1.5;
            float rays=pow(abs(cos(atan2(delta.y,delta.x)*3)),48.0)*exp(-r*12)*0.12;
            color+=rays;
            for(int i=0;i<3;i++) {
                float k=0.6+float(i)*0.5;
                float radius=0.025+float(i)*0.02;
                float g=length((in.uv-solar*(1-k))*float2(u.viewport.x/u.viewport.y,1));
                color+=float3(0.02,0.07,0.065)*exp(-pow(g/radius,4.0));
            }
        }
    }
    return float4(color,1);
}
vertex Raster star_vertex(uint id [[vertex_id]], uint instance [[instance_id]],
                          const device StarInstance *stars [[buffer(0)]], constant Uniforms &u [[buffer(1)]]) {
    Raster o;
    StarInstance star=stars[instance];
    float3 d=local(star.positionMagnitude.xyz,u);
    float flux=pow(10.0,-0.4*star.positionMagnitude.w);
    float fov=u.viewport.w;
    float fNumber=mix(2.8,3.5,clamp((105-fov)/100,0.0,1.0));
    float exposure=2.8*pow(max(1.0,105.0/max(fov,1e-4)),1.75);
    float omega=0.9*star.colorWavelength.w*fNumber;
    // A star keeps its phase when culling or tier changes reorder the buffer.
    float phase=fract(sin(dot(star.positionMagnitude.xyz,float3(12.9898,78.233,37.719)))*43758.5453)*6.2831853;
    float importance=1-smoothstep(-0.5,3.5,star.positionMagnitude.w);
    // The same flux/Gaussian optics, with subdued altitude-dependent scintillation.
    float flicker=1.0-importance*(0.025+0.075*exp(-max(d.y,0.0)*5.0))*(0.5+0.5*sin(u.effects.z*4+phase));
    float extinction=exp(-0.16/max(0.08,d.y));
    float multiplier=flux*exposure*flicker*extinction*(1-u.effects.x)*(1.15+importance*2.8);
    float size=omega*sqrt(max(0.01,-0.5*log(1.0/255.0/max(multiplier,0.004))));
    o.position=project(d,u);
    // Original sensor-pixel calibration, normalized at 1000 drawable pixels.
    float pixels=clamp(size/4.63e-6*u.viewport.y*0.0005,0.65,24.0);
    float flarePixels=mix(5.0,17.0,importance)*u.effects.w;
    float radius=importance>0.01 ? max(pixels,flarePixels) : pixels;
    size*=radius/pixels;
    o.position.xy+=billboardQuad[id]*radius*2.0/u.viewport.xy*o.position.w;
    if(d.y<0 || behindGround(d) || multiplier<0.004) o.position=float4(2,2,2,1);
    o.uv=billboardQuad[id]*0.5+0.5;
    o.color=float4(star.colorWavelength.rgb,1);
    o.optics=float4(omega,size,multiplier,importance*(1-u.effects.x)*extinction);
    return o;
}
fragment float4 star_fragment(Raster in [[stage_in]]) {
    float dist=length(in.uv-0.5);
    float irradiance=exp(-2*pow(dist*2*in.optics.y,2)/pow(in.optics.x,2))*in.optics.z;
    float alpha=saturate(irradiance);
    float3 color=mix(in.color.rgb,float3(1),smoothstep(0.4,2.0,irradiance)*0.65);
    if(in.optics.w>0.01) {
        float2 q=(in.uv-0.5)*2;
        float r=length(q);
        float cross=exp(-abs(q.x)*48)*exp(-abs(q.y)*3.2)+exp(-abs(q.y)*48)*exp(-abs(q.x)*3.2);
        float diagonal=(exp(-abs(q.x-q.y)*95)+exp(-abs(q.x+q.y)*95))*exp(-r*9)*0.25;
        float halo=exp(-r*7)*0.18;
        float flare=(cross*1.1+diagonal+halo)*in.optics.w*pow(saturate(1-r),1.5);
        alpha=saturate(alpha+flare);
    }
    return float4(color*alpha,alpha);
}
// Screen-space segment quads keep a consistent point width at every zoom and
// screen density. Near-plane clipping prevents giant wedges behind the camera.
vertex Raster line_vertex(uint id [[vertex_id]], uint instance [[instance_id]],
                          const device LineVertex *vertices [[buffer(0)]], constant Uniforms &u [[buffer(1)]]) {
    Raster o;
    LineVertex a=vertices[instance*2], b=vertices[instance*2+1];
    float3 da=a.position.w>0.5 ? local(a.position.xyz,u) : a.position.xyz;
    float3 db=b.position.w>0.5 ? local(b.position.xyz,u) : b.position.xyz;
    float4 ca=project(da,u), cb=project(db,u);
    float ta=a.profile.x, tb=b.profile.x;
    float sa=a.profile.z, sb=b.profile.z;
    const float near=0.005;
    if(ca.w<near && cb.w<near) {
        o.position=float4(2,2,2,1); o.uv=0; o.color=0; o.optics=0; o.flow=0; return o;
    }
    if(ca.w<near) {
        float t=(near-ca.w)/(cb.w-ca.w); da=mix(da,db,t); ta=mix(ta,tb,t); sa=mix(sa,sb,t); ca=project(da,u);
    } else if(cb.w<near) {
        float t=(near-cb.w)/(ca.w-cb.w); db=mix(db,da,t); tb=mix(tb,ta,t); sb=mix(sb,sa,t); cb=project(db,u);
    }
    float2 delta=(cb.xy/cb.w-ca.xy/ca.w)*u.viewport.xy*0.5;
    float2 perpendicular=float2(-delta.y,delta.x)/max(length(delta),0.001);
    float coreHalf=(a.position.w>0.5 ? 0.7 : 1.0)*u.effects.w;
    float halfWidth=coreHalf+0.75;
    float along=billboardQuad[id].x*0.5+0.5;
    float side=billboardQuad[id].y;
    o.position=mix(ca,cb,along);
    o.position.xy+=perpendicular*(side*halfWidth)*2/u.viewport.xy*o.position.w;
    o.uv=float2(side*halfWidth,coreHalf);
    o.color=mix(a.color,b.color,along);
    if(a.profile.y>1.5) o.color.a*=1-smoothstep(-6.0,0.0,u.sun.w);
    o.optics=float4(mix(da,db,along),a.position.w>0.5 && a.profile.y<0.5 ? mix(ta,tb,along) : -1);
    // A uniform angular scale keeps dots and pulses coherent across segments.
    o.flow=float4(mix(ta,tb,along),a.profile.y,mix(sa,sb,along),
                  max(2*atan(u.viewport.z)*u.effects.w/u.viewport.y,1e-9));
    return o;
}
fragment float4 line_fragment(Raster in [[stage_in]], constant float2 &flowTime [[buffer(1)]]) {
    // Convert the full-edge parameter gradient to a five-point star clearance.
    // Screen-space derivatives keep the gap stable while zooming. Short edges
    // retain their middle section, including during the contraction animation.
    float edgeParameter=in.optics.w;
    float parameterPerPixel=length(float2(dfdx(edgeParameter),dfdy(edgeParameter)));
    float gap=min(0.2,5.0*(in.uv.y/0.7)*parameterPerPixel);
    if(behindGround(in.optics.xyz)) discard_fragment();
    if(edgeParameter>=0) {
        if(edgeParameter<=gap || edgeParameter>=1-gap) discard_fragment();
        edgeParameter=(edgeParameter-gap)/(1-2*gap);
    }
    float taper=edgeParameter>=0 ? pow(max(0.0,sin(M_PI_F*saturate(edgeParameter))),0.65) : 1;
    float halfWidth=in.uv.y*(0.12+0.88*taper);
    float coverage=1-smoothstep(halfWidth,halfWidth+0.75,abs(in.uv.x));
    if(in.flow.y>0.5 && in.flow.z>flowTime.y) {
        // Future path: round dots anchored to the orbit, never marching backward
        // when the preview time changes. The separate highlight still flows forward.
        float radiansPerPixel=max(length(float2(dfdx(in.flow.x),dfdy(in.flow.x))),0.000001);
        float spacing=in.flow.y>1.5 ? in.flow.w*10.0 : 0.008;
        float along=(fract(in.flow.x/spacing)-0.5)*spacing/radiansPerPixel;
        coverage=1-smoothstep(halfWidth,halfWidth+0.75,length(float2(along,in.uv.x)));
    }
    float alpha=in.color.a*coverage*taper;
    float3 color=in.color.rgb;
    if(in.flow.y>0.5 && flowTime.x>=0) {
        // A continuous angular coordinate keeps pulses joined across segments.
        // Increasing phase travels from rise toward set, even when preview is paused.
        float period=in.flow.y>1.5 ? in.flow.w*160.0 : 0.35;
        float phase=fract(in.flow.x/period-flowTime.x*0.45);
        float pulse=smoothstep(0.35,0.8,phase)*(1-smoothstep(0.8,0.94,phase));
        alpha*=0.65+0.35*pulse;
        color=mix(color,float3(0.82,1.0,0.97),0.7*pulse);
    }
    return float4(color*alpha,alpha);
}
vertex Raster sprite_vertex(uint id [[vertex_id]], constant Sprite &sprite [[buffer(0)]], constant Uniforms &u [[buffer(1)]]) {
    Raster o; float3 d=sprite.options.x>0.5 ? local(sprite.positionSize.xyz,u) : sprite.positionSize.xyz;
    o.position=project(d,u);
    float2 q=billboardQuad[id];
    float a=sprite.options.z;
    q=float2(q.x*cos(a)-q.y*sin(a),q.x*sin(a)+q.y*cos(a));
    float2 pixels=float2(sprite.positionSize.w,sprite.positionSize.w*sprite.options.y);
    o.position.xy+=q*pixels/u.viewport.xy*o.position.w;
    if(d.y<0 || ((sprite.options.w<0.5 || sprite.options.w>1.5) && behindGround(d))) o.position=float4(2,2,2,1);
    o.uv=sprite.uvRect.xy+(billboardQuad[id]*float2(0.5,-0.5)+0.5)*sprite.uvRect.zw;
    o.color=sprite.tint;
    // Atmospheric scattering is in front of a planet, including its night side.
    // Keep the opaque disk (so background stars remain occulted) and add the same
    // local daylight atmosphere used by the sky instead of a black daytime disk.
    o.optics=float4(atmosphere(d,u)*u.effects.x,sprite.options.w>1.5 && sprite.options.w<2.5 ? 1.0 : 0.0);
    if(sprite.options.w>2.5) {
        // One color for the whole label, chosen from its local sky plus the same
        // broad solar glare used by background_fragment. No stroke or shadow.
        float3 background=atmosphere(d,u);
        float facing=dot(u.sun.xyz,u.forward.xyz);
        if(u.sun.w>0 && facing>0) {
            float4 solar=project(u.sun.xyz,u), label=project(d,u);
            float2 delta=(label.xy/label.w-solar.xy/solar.w)*float2(u.viewport.x/u.viewport.y,1);
            float r2=dot(delta,delta);
            background+=float3(1,0.75,0.42)*exp(-r2*40)*0.5;
            background+=float3(1,0.90,0.7)*exp(-r2*700)*1.5;
        }
        float luminance=dot(background,float3(0.2126,0.7152,0.0722));
        o.color.rgb*=luminance>0.20 ? float3(0.005,0.01,0.02) : float3(1,0.92,0.75);
    }
    return o;
}
fragment float4 sprite_fragment(Raster in [[stage_in]], texture2d<float> tex [[texture(0)]]) {
    constexpr sampler s(address::clamp_to_edge,filter::linear);
    float4 c=tex.sample(s,in.uv);
    c.rgb+=in.optics.xyz*c.a*in.optics.w;
    return c*in.color;
}

// Optical structure of the main C/B/A rings, radii in Saturn equatorial radii.
// NASA NSSDCA: 74658, 91975, 117507, 122340, 136780 km / 60268 km.
float saturnRingOpacity(float radius, float aa) {
    float c = smoothstep(74658.0/60268.0-aa,74658.0/60268.0+aa,radius);
    float b = smoothstep(91975.0/60268.0-aa,91975.0/60268.0+aa,radius);
    float gap = smoothstep(117507.0/60268.0-aa,117507.0/60268.0+aa,radius);
    float a = smoothstep(122340.0/60268.0-aa,122340.0/60268.0+aa,radius);
    float end = smoothstep(136780.0/60268.0-aa,136780.0/60268.0+aa,radius);
    return max(0.0,0.23*c + 0.72*b - 0.92*gap + 0.73*a - 0.76*end);
}

// Orthographic ray/oblate-spheroid intersection. Geometry and sunlight use a
// pole-up disk frame for both the resolved sky disk and the selected miniature.
fragment float4 planet_icon_fragment(Raster in [[stage_in]], constant float4 &p [[buffer(0)]],
                                     constant float4 &sun [[buffer(1)]], constant float4 &shape [[buffer(2)]],
                                     texture2d<float> surface [[texture(0)]],
                                     texture2d<float> clouds [[texture(1)]]) {
    int kind=int(p.x);
    float c=cos(p.z), s=sin(p.z);
    float2 q=float2(c*in.uv.x+s*in.uv.y,-s*in.uv.x+c*in.uv.y)/shape.y;
    float3 light=normalize(sun.xyz);
    float opening=sin(p.w), poleHeight=cos(p.w);
    float3 pole=float3(0,poleHeight,opening);
    float flattening=1/(shape.x*shape.x)-1;
    float projectedPolar=sqrt(opening*opening+shape.x*shape.x*poleHeight*poleHeight);
    float silhouette=length(float2(q.x,q.y/projectedPolar));
    float aa=max(fwidth(silhouette),0.001);
    float a=1+flattening*pole.z*pole.z;
    float b=flattening*q.y*pole.y*pole.z;
    float cc=dot(q,q)+flattening*q.y*q.y*pole.y*pole.y-1;
    float discriminant=b*b-a*cc;
    float z=(-b+sqrt(max(0.0,discriminant)))/a;
    float3 hit=float3(q,z);
    float3 normal=normalize(hit+flattening*dot(hit,pole)*pole);
    float4 globe=0, ring=0;

    if(silhouette<1+aa) {
        float3 material=normalize(float3(hit.x,poleHeight*hit.y+opening*hit.z,-opening*hit.y+poleHeight*hit.z));
        float3 rotated=float3(cos(p.y)*material.x-sin(p.y)*material.z,material.y,sin(p.y)*material.x+cos(p.y)*material.z);
        float2 uv=float2(0.5+atan2(rotated.x,rotated.z)/(2*M_PI_F),0.5-asin(clamp(rotated.y,-1.0,1.0))/M_PI_F);
        constexpr sampler mapSampler(s_address::repeat,t_address::clamp_to_edge,filter::linear,mip_filter::linear);
        float2 dx=dfdx(uv), dy=dfdy(uv);
        dx.x-=round(dx.x); dy.x-=round(dy.x);
        float3 albedo=surface.sample(mapSampler,uv,gradient2d(dx,dy)).rgb;
        if(kind==2) {
            float cloud=clouds.sample(mapSampler,uv,gradient2d(dx,dy)).r;
            albedo=mix(albedo,float3(0.92),smoothstep(0.1,0.85,cloud)*0.85);
        }
        // No fixed ambient fill: the night side must remain dark at crescent phase.
        float illumination=pow(max(dot(normal,light),0.0),0.65);
        if(kind==5 && abs(dot(light,pole))>0.0001) {
            float t=-dot(hit,pole)/dot(light,pole);
            if(t>0) illumination*=1-saturnRingOpacity(length(hit+t*light),0.006)*0.90;
        }
        float3 color=albedo*illumination;
        if(kind!=0) {
            float3 haze=kind==1 ? float3(0.9,0.65,0.28) : kind==3 ? float3(0.7,0.25,0.10) : float3(0.15,0.45,0.9);
            if(kind==4 || kind==5) haze=float3(0.65,0.49,0.30);
            if(kind==6) haze=float3(0.25,0.65,0.75);
            color+=haze*pow(1-max(normal.z,0.0),3.0)*0.12*illumination;
        }
        float coverage=1-smoothstep(1-aa,1+aa,silhouette);
        globe=float4(color*coverage,coverage);
    }

    float ringZ=0;
    if(kind==5 && abs(opening)>0.00001) {
        ringZ=-q.y*poleHeight/opening;
        float3 ringHit=float3(q,ringZ);
        float ringRadius=length(ringHit);
        float ringAA=min(0.03,max(fwidth(ringRadius),0.001));
        float opacity=saturnRingOpacity(ringRadius,ringAA);
        // Physical rings approach zero projected area when viewed edge-on.
        opacity*=min(1.0,abs(opening)/max(fwidth(q.y),0.0001));
        float bands=0.94+0.035*sin(ringRadius*80)+0.025*sin(ringRadius*173);
        float brightness=0.35+0.65*sqrt(abs(dot(pole,light)));
        // Trace toward the Sun to cast the oblate globe's shadow on the rings.
        float qa=1+flattening*pow(dot(light,pole),2.0);
        float qb=dot(ringHit,light)+flattening*dot(ringHit,pole)*dot(light,pole);
        float qc=dot(ringHit,ringHit)+flattening*pow(dot(ringHit,pole),2.0)-1;
        float shadowDisc=qb*qb-qa*qc;
        if(qb<0 && shadowDisc>0) brightness*=0.03;
        ring=float4(float3(0.69,0.60,0.44)*bands*brightness*opacity,opacity);
    }
    return ringZ>z ? ring+globe*(1-ring.a) : globe+ring*(1-globe.a);
}

// One instanced dot per ephemeris sample: daily planets, 12-hour Moon.
vertex Raster motion_trail_vertex(uint id [[vertex_id]], uint instance [[instance_id]],
    const device LineVertex *points [[buffer(0)]], constant Uniforms &u [[buffer(1)]]) {
    Raster o;
    LineVertex point=points[instance];
    float3 direction=local(point.position.xyz,u);
    o.position=project(direction,u);
    float radius=(point.profile.x>0 ? point.profile.x : 1.35)*u.effects.w;
    float2 pixel=billboardQuad[id]*(radius+0.75);
    o.position.xy+=pixel*2/u.viewport.xy*o.position.w;
    if(o.position.w<=0.005 || behindGround(direction)) o.position=float4(2,2,2,1);
    o.uv=pixel; o.optics=float4(radius,0,0,0); o.flow=0;
    o.color=point.color;
    // These are sky annotations, not self-luminous objects in the daytime sky.
    o.color.a*=1-smoothstep(-6.0,0.0,u.sun.w);
    return o;
}
fragment float4 motion_trail_fragment(Raster in [[stage_in]]) {
    float alpha=in.color.a*(1-smoothstep(in.optics.x,in.optics.x+0.75,length(in.uv)));
    return float4(in.color.rgb*alpha,alpha);
}
