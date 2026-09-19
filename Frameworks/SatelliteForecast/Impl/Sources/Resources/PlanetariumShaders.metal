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
struct Raster { float4 position [[position]]; float2 uv; float4 color; float4 optics; };

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
float3 galacticLight(float3 d, constant Uniforms &u,
                     texture2d<float> milkyLeft, texture2d<float> milkyRight) {
    float3 eq=d.x*u.east.xyz+d.y*u.zenith.xyz-d.z*u.north.xyz;
    float3 gal=float3(dot(eq,float3(-0.05487556,-0.87343709,-0.48383502)),dot(eq,float3(0.49410943,-0.44482963,0.74698224)),dot(eq,float3(-0.86766615,-0.19807637,0.45598378)));
    float2 uv=float2(0.5-atan2(gal.y,gal.x)/(2*M_PI_F),0.5-asin(clamp(gal.z,-1.0,1.0))/M_PI_F);
    constexpr sampler skySampler(address::clamp_to_edge, filter::linear, mip_filter::linear);
    // Explicit LOD avoids derivative discontinuities at longitude and tile seams.
    float2 dx=dfdx(uv), dy=dfdy(uv);
    dx.x-=round(dx.x); dy.x-=round(dy.x);
    float2 dimensions=float2(16384,8192);
    float lod=clamp(log2(max(length(dx*dimensions),length(dy*dimensions)))-0.35,0.0,13.0);
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
    float phase=fract(sin(float(instance)*12.9898+78.233)*43758.5453)*6.2831853;
    // The same flux/Gaussian optics, with subdued altitude-dependent scintillation.
    float flicker=1.0-(0.04+0.12*exp(-max(d.y,0.0)*5.0))*(0.5+0.5*sin(u.effects.z*6+phase));
    float extinction=exp(-0.16/max(0.08,d.y));
    float importance=1-smoothstep(-0.5,3.5,star.positionMagnitude.w);
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
    const float near=0.005;
    if(ca.w<near && cb.w<near) {
        o.position=float4(2,2,2,1); o.uv=0; o.color=0; o.optics=0; return o;
    }
    if(ca.w<near) {
        float t=(near-ca.w)/(cb.w-ca.w); da=mix(da,db,t); ta=mix(ta,tb,t); ca=project(da,u);
    } else if(cb.w<near) {
        float t=(near-cb.w)/(ca.w-cb.w); db=mix(db,da,t); tb=mix(tb,ta,t); cb=project(db,u);
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
    o.optics=float4(mix(da,db,along),a.position.w>0.5 ? mix(ta,tb,along) : -1);
    return o;
}
fragment float4 line_fragment(Raster in [[stage_in]]) {
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
    float alpha=in.color.a*coverage*taper;
    return float4(in.color.rgb*alpha,alpha);
}
vertex Raster sprite_vertex(uint id [[vertex_id]], constant Sprite &sprite [[buffer(0)]], constant Uniforms &u [[buffer(1)]]) {
    Raster o; float3 d=sprite.options.x>0.5 ? local(sprite.positionSize.xyz,u) : sprite.positionSize.xyz;
    o.position=project(d,u);
    float2 q=billboardQuad[id];
    float a=sprite.options.z;
    q=float2(q.x*cos(a)-q.y*sin(a),q.x*sin(a)+q.y*cos(a));
    float2 pixels=float2(sprite.positionSize.w,sprite.positionSize.w*sprite.options.y);
    o.position.xy+=q*pixels/u.viewport.xy*o.position.w;
    if(d.y<0 || (sprite.options.w<0.5 && behindGround(d))) o.position=float4(2,2,2,1);
    o.uv=sprite.uvRect.xy+(billboardQuad[id]*float2(0.5,-0.5)+0.5)*sprite.uvRect.zw;
    o.color=sprite.tint; return o;
}
fragment float4 sprite_fragment(Raster in [[stage_in]], texture2d<float> tex [[texture(0)]]) {
    constexpr sampler s(address::clamp_to_edge,filter::linear);
    float4 c=tex.sample(s,in.uv); return c*in.color;
}

// Orthographic ray/sphere intersection for the selection-card miniature.
// Texture coordinates rotate on the 3D surface; lighting remains in view space.
fragment float4 planet_icon_fragment(Raster in [[stage_in]], constant float4 &p [[buffer(0)]],
                                     texture2d<float> surface [[texture(0)]],
                                     texture2d<float> clouds [[texture(1)]]) {
    int kind=int(p.x);
    float radius=kind==5 ? 0.48 : 0.76;
    float2 screen=in.uv;
    float c=cos(p.z), s=sin(p.z);
    float2 q=float2(c*screen.x+s*screen.y,-s*screen.x+c*screen.y)/radius;
    float r=length(q), aa=max(fwidth(r),0.001);
    float4 result=0;
    // Saturn's inclined rings: render the far half behind the globe, then
    // the near half in front. The gap between ring bands stays transparent.
    float ringRadius=length(float2(q.x,q.y/0.36));
    float ringAA=max(fwidth(ringRadius),0.008);
    float ringCoverage=smoothstep(1.18-ringAA,1.18+ringAA,ringRadius)
        *(1-smoothstep(1.91-ringAA,1.91+ringAA,ringRadius));
    ringCoverage*=1-0.8*exp(-pow((ringRadius-1.64)/0.035,2));
    float bands=0.65+0.12*sin(ringRadius*72)+0.10*sin(ringRadius*131);
    float4 ring=float4(float3(0.62,0.51,0.34)*bands*ringCoverage,ringCoverage*0.85);
    if(kind==5 && q.y>0) result=ring;
    bool atmospheric=kind!=0;
    float3 haze=kind==1 ? float3(0.9,0.65,0.28) : kind==3 ? float3(0.7,0.25,0.10) : float3(0.15,0.45,0.9);
    if(kind==4 || kind==5) haze=float3(0.65,0.49,0.30);
    if(kind==6) haze=float3(0.25,0.65,0.75);
    float strength=kind==1 ? 0.35 : kind==3 ? 0.07 : 0.18;
    if(atmospheric) {
        float halo=exp(-max(r-1,0.0)*35)*strength*smoothstep(0.9,1.0,r)*(1-smoothstep(1.07,1.16,r));
        result=float4(haze*halo,halo)+result*(1-halo);
    }
    if(r<1+aa) {
        float3 n=float3(q,sqrt(max(0.0,1-dot(q,q))));
        n=normalize(n);
        // Inverse body rotation maps the view-space hit into material space.
        float3 rotated=float3(cos(p.y)*n.x-sin(p.y)*n.z,n.y,sin(p.y)*n.x+cos(p.y)*n.z);
        float2 uv=float2(0.5+atan2(rotated.x,rotated.z)/(2*M_PI_F),0.5-asin(clamp(rotated.y,-1.0,1.0))/M_PI_F);
        constexpr sampler mapSampler(s_address::repeat,t_address::clamp_to_edge,filter::linear,mip_filter::linear);
        // Wrap longitude derivatives as well as coordinates, avoiding a blurry
        // mip stripe when the map seam rotates across the visible hemisphere.
        float2 dx=dfdx(uv), dy=dfdy(uv);
        dx.x-=round(dx.x); dy.x-=round(dy.x);
        float3 albedo=surface.sample(mapSampler,uv,gradient2d(dx,dy)).rgb;
        if(kind==2) {
            float cloud=clouds.sample(mapSampler,uv,gradient2d(dx,dy)).r;
            albedo=mix(albedo,float3(0.92),smoothstep(0.1,0.85,cloud)*0.85);
        }
        // Venus's map is its opaque cloud deck, never the radar surface map.
        float3 viewNormal=float3(c*n.x-s*n.y,s*n.x+c*n.y,n.z);
        float light=max(dot(viewNormal,normalize(float3(-0.45,0.55,1))),0.0);
        float3 color=albedo*(0.12+0.88*light);
        if(atmospheric) color+=haze*pow(1-n.z,3.0)*strength*(0.25+0.75*light);
        float coverage=1-smoothstep(1-aa,1+aa,r);
        result=float4(color*coverage,coverage)+result*(1-coverage);
    }
    if(kind==5 && q.y<=0) result=ring+result*(1-ring.a);
    return result;
}
