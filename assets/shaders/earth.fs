#if defined(VERTEX) || __VERSION__ > 100 || defined(GL_FRAGMENT_PRECISION_HIGH)
    #define PRECISION highp
#else
    #define PRECISION mediump
#endif

extern PRECISION vec2 earth;
extern PRECISION number dissolve;
extern PRECISION number time;
// (sprite_pos_x, sprite_pos_y, sprite_width, sprite_height) [not normalized]
extern PRECISION vec4 texture_details;
// (width, height) for atlas texture [not normalized]
extern PRECISION vec2 image_details;
extern bool shadow;
extern PRECISION vec4 burn_colour_1;
extern PRECISION vec4 burn_colour_2;

// for transforming the card while your mouse is on it
extern PRECISION vec2 mouse_screen_pos;
extern PRECISION float hovering;
extern PRECISION float screen_scale;

float saturate1(float x) {
    return clamp(x, 0.0, 1.0);
}

vec3 saturate3(vec3 x) {
    return clamp(x, vec3(0.0), vec3(1.0));
}

float hash12(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float valueNoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);

    float a = hash12(i);
    float b = hash12(i + vec2(1.0, 0.0));
    float c = hash12(i + vec2(0.0, 1.0));
    float d = hash12(i + vec2(1.0, 1.0));

    vec2 u = f * f * (3.0 - 2.0 * f);

    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;

    v += a * valueNoise(p); p *= 2.02; a *= 0.50;
    v += a * valueNoise(p); p *= 2.03; a *= 0.50;
    v += a * valueNoise(p); p *= 2.01; a *= 0.50;
    v += a * valueNoise(p); p *= 2.04; a *= 0.50;
    v += a * valueNoise(p);

    return v;
}

float ridge(float x) {
    return 1.0 - abs(2.0 * x - 1.0);
}

float ridgedFbm(vec2 p) {
    float v = 0.0;
    float a = 0.5;

    v += a * ridge(valueNoise(p)); p *= 2.07; a *= 0.52;
    v += a * ridge(valueNoise(p)); p *= 2.11; a *= 0.50;
    v += a * ridge(valueNoise(p)); p *= 2.03; a *= 0.48;
    v += a * ridge(valueNoise(p)); p *= 2.17; a *= 0.46;
    v += a * ridge(valueNoise(p));

    return v;
}

float roundedRectSDF(vec2 uv, float radius) {
    vec2 q = abs(uv - 0.5) - vec2(0.5 - radius);
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

float roundedRectAlpha(vec2 uv, float radius) {
    float d = roundedRectSDF(uv, radius);
    return 1.0 - smoothstep(0.0, 0.012, d);
}

float minEdgeDistance(vec2 uv) {
    return min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
}

float rectRadialDistance(vec2 uv) {
    vec2 c = abs(uv - 0.5);
    return max(c.x, c.y) * 2.0;
}

vec2 local_uv_from_texture_coords(vec2 texture_coords) {
    return (((texture_coords) * (image_details)) - texture_details.xy * texture_details.ba) / texture_details.ba;
}

vec2 texture_coords_from_local_uv(vec2 uv) {
    vec2 sprite_pixels = texture_details.xy * texture_details.ba + uv * texture_details.ba;
    return sprite_pixels / image_details;
}

vec4 dissolve_mask(vec4 tex, vec2 texture_coords, vec2 uv) {
    if (dissolve < 0.001) {
        return vec4(shadow ? vec3(0.0) : tex.xyz, shadow ? tex.a * 0.3 : tex.a);
    }

    float adjusted_dissolve = (dissolve * dissolve * (3.0 - 2.0 * dissolve)) * 1.02 - 0.01;
    float t = time * 10.0 + 2003.0;

    vec2 floored_uv = (floor((uv * texture_details.ba))) / max(texture_details.b, texture_details.a);
    vec2 uv_scaled_centered = (floored_uv - 0.5) * 2.3 * max(texture_details.b, texture_details.a);

    vec2 field_part1 = uv_scaled_centered + 50.0 * vec2(sin(-t / 143.6340), cos(-t / 99.4324));
    vec2 field_part2 = uv_scaled_centered + 50.0 * vec2(cos(t / 53.1532), cos(t / 61.4532));
    vec2 field_part3 = uv_scaled_centered + 50.0 * vec2(sin(-t / 87.53218), sin(-t / 49.0000));

    float field = (1.0 + (
        cos(length(field_part1) / 19.483) +
        sin(length(field_part2) / 33.155) * cos(field_part2.y / 15.73) +
        cos(length(field_part3) / 27.193) * sin(field_part3.x / 21.92)
    )) / 2.0;

    vec2 borders = vec2(0.2, 0.8);

    float res = (0.5 + 0.5 * cos((adjusted_dissolve) / 82.612 + (field - 0.5) * 3.14))
        - (floored_uv.x > borders.y ? (floored_uv.x - borders.y) * (5.0 + 5.0 * dissolve) : 0.0) * dissolve
        - (floored_uv.y > borders.y ? (floored_uv.y - borders.y) * (5.0 + 5.0 * dissolve) : 0.0) * dissolve
        - (floored_uv.x < borders.x ? (borders.x - floored_uv.x) * (5.0 + 5.0 * dissolve) : 0.0) * dissolve
        - (floored_uv.y < borders.x ? (borders.x - floored_uv.y) * (5.0 + 5.0 * dissolve) : 0.0) * dissolve;

    if (tex.a > 0.01 && burn_colour_1.a > 0.01 && !shadow &&
        res < adjusted_dissolve + 0.8 * (0.5 - abs(adjusted_dissolve - 0.5)) &&
        res > adjusted_dissolve) {
        if (res < adjusted_dissolve + 0.5 * (0.5 - abs(adjusted_dissolve - 0.5)) &&
            res > adjusted_dissolve) {
            tex.rgba = burn_colour_1.rgba;
        } else if (burn_colour_2.a > 0.01) {
            tex.rgba = burn_colour_2.rgba;
        }
    }

    return vec4(shadow ? vec3(0.0) : tex.xyz, res > adjusted_dissolve ? (shadow ? tex.a * 0.3 : tex.a) : 0.0);
}


float sedimentStrata(vec2 uv, float time, float tectonicScale) {
    float t = time;

    float warpA = fbm(uv * vec2(4.0, 8.0) + vec2(t * 0.015, -t * 0.010));
    float warpB = fbm(uv * vec2(11.0, 5.0) + vec2(-t * 0.012, t * 0.018));

    float foldedY = uv.y + 0.060 * (warpA - 0.5) + 0.030 * sin(uv.x * 9.0 + warpB * 3.0);

    float layers = 0.5 + 0.5 * sin(foldedY * mix(22.0, 34.0, saturate1(tectonicScale)) + warpB * 4.0);

    float thinLayer = smoothstep(0.58, 0.76, layers);
    float hardLayer = smoothstep(0.82, 0.95, layers);

    return thinLayer * 0.65 + hardLayer * 0.35;
}

vec2 cellOffset(vec2 id, float time) {
    float a = 6.2831853 * hash12(id + vec2(17.13, 9.41));
    float r = hash12(id + vec2(3.77, 21.91));

    vec2 o = vec2(cos(a), sin(a));
    o *= 0.20 + 0.12 * r;

    o += 0.030 * vec2(
        sin(time * 0.08 + r * 6.0),
        cos(time * 0.07 + r * 5.0)
    );

    return vec2(0.5) + o;
}

float crackNetwork(vec2 p, float time) {
    vec2 i = floor(p);
    vec2 f = fract(p);

    float f1 = 100.0;
    float f2 = 100.0;

    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 g = vec2(float(x), float(y));
            vec2 id = i + g;
            vec2 o = cellOffset(id, time);
            vec2 r = g + o - f;
            float d = dot(r, r);

            if (d < f1) {
                f2 = f1;
                f1 = d;
            } else if (d < f2) {
                f2 = d;
            }
        }
    }

    float edge = sqrt(f2) - sqrt(f1);
    return 1.0 - smoothstep(0.018, 0.060, edge);
}

float mineralVeins(vec2 uv, float time, float tectonicScale) {
    float t = time;

    vec2 warp = vec2(
        fbm(uv * 5.0 + vec2(t * 0.020, -t * 0.015)),
        fbm(uv * 5.0 + vec2(-t * 0.012, t * 0.018))
    ) - 0.5;

    vec2 p = uv + warp * 0.10;

    float veinA = ridgedFbm(p * vec2(13.0, 21.0) + vec2(t * 0.025, -t * 0.020));
    float veinB = ridgedFbm(p * vec2(27.0, 12.0) + vec2(-t * 0.030, t * 0.018));

    float veins = smoothstep(0.70, 0.97, veinA) * 0.62 + smoothstep(0.76, 0.99, veinB) * 0.38;

    float pulse = 0.76 + 0.24 * sin(time * 1.6 + fbm(uv * 4.0) * 6.0);

    veins *= pulse;
    veins *= mix(0.70, 1.35, saturate1(tectonicScale));

    return veins;
}

float crystalFacetField(vec2 uv, float time, float tectonicScale) {
    vec2 center = uv - 0.5;
    float radial = rectRadialDistance(uv);

    float ang = atan(center.y, center.x);
    float r = length(center);

    float facets = 0.5 + 0.5 * sin(ang * 7.0 + r * 28.0 - time * 0.55 + fbm(uv * 6.0) * 4.0);

    float shards = smoothstep(0.62, 0.93, facets) * smoothstep(0.12, 0.88, radial) * (1.0 - smoothstep(1.02, 1.28, radial));

    float glint = 0.70 + 0.30 * sin(time * 5.5 + ang * 3.0);

    shards *= glint;
    shards *= mix(0.55, 1.25, saturate1(tectonicScale));

    return shards;
}

float dustMotes(vec2 uv, float time, float intensity) {
    vec2 p = uv * vec2(7.0, 11.0);

    p.y -= time * 0.10;
    p.x += sin(time * 0.35 + uv.y * 7.0) * 0.18;

    vec2 id = floor(p);
    vec2 gv = fract(p) - 0.5;

    float rnd = hash12(id);
    vec2 offset = vec2(
        hash12(id + vec2(3.1, 7.7)),
        hash12(id + vec2(8.9, 2.4))
    ) - 0.5;

    gv -= offset * 0.62;

    float d = length(gv);
    float radius = mix(0.010, 0.034, rnd);

    float mote = 1.0 - smoothstep(radius * 0.4, radius, d);
    mote *= step(0.72, rnd);

    float shimmer = 0.45 + 0.55 * sin(time * 3.0 + rnd * 24.0);

    return mote * shimmer * intensity;
}

vec2 earthDisplacement(vec2 uv, float time, float intensity, float tectonicScale) {
    float t = time;

    vec2 p = uv - 0.5;
    float radial = rectRadialDistance(uv);

    float strata = sedimentStrata(uv, time, tectonicScale);
    float cracks = crackNetwork(uv * 7.5, time * 0.18);
    float stoneNoise = fbm(uv * 12.0 + vec2(t * 0.010, -t * 0.008));

    vec2 displacement;
    displacement.x = 0.0032 * sin(uv.y * 18.0 + strata * 3.5 + t * 0.25) + 0.0040 * (stoneNoise - 0.5);
    displacement.y = 0.0024 * sin(uv.x * 14.0 - strata * 2.5 - t * 0.20) + 0.0028 * (fbm(uv * 15.0 + vec2(-t * 0.010, t * 0.012)) - 0.5);

    vec2 crackPush = normalize(p + vec2(0.0001));
    displacement += crackPush * cracks * 0.0035;

    float seismic = sin(length(p) * 34.0 - time * 2.0) * (1.0 - smoothstep(0.12, 0.92, radial));
    displacement += normalize(p + vec2(0.0001)) * seismic * 0.0018;

    displacement *= intensity;
    displacement *= mix(0.55, 1.45, saturate1(tectonicScale));

    return displacement;
}

vec4 earthEdition(vec4 baseTex, vec2 uv, float time, float intensity, float tectonicScale) {
    float cardAlpha = roundedRectAlpha(uv, 0.065);
    float edgeDist = minEdgeDistance(uv);
    float radial = rectRadialDistance(uv);

    baseTex.a *= cardAlpha;

    float stoneGrain = fbm(uv * vec2(18.0, 24.0) + vec2(time * 0.006, -time * 0.004));
    float coarseStone = fbm(uv * vec2(5.0, 7.0) + vec2(-time * 0.004, time * 0.005));
    float strata = sedimentStrata(uv, time, tectonicScale);

    vec3 ochre = vec3(0.54, 0.39, 0.20);
    vec3 clay = vec3(0.40, 0.25, 0.13);
    vec3 deepSoil = vec3(0.13, 0.095, 0.055);
    vec3 mossShadow = vec3(0.070, 0.125, 0.055);
    vec3 granite = vec3(0.43, 0.40, 0.34);

    float stoneMask = smoothstep(0.04, 0.88, radial + coarseStone * 0.12) * cardAlpha * intensity;

    baseTex.rgb = mix(baseTex.rgb, granite, stoneMask * 0.28);
    baseTex.rgb = mix(baseTex.rgb, ochre, strata * 0.24 * intensity * cardAlpha);
    baseTex.rgb = mix(baseTex.rgb, clay, stoneGrain * 0.28 * intensity * cardAlpha);

    float edgeWeight = 1.0 - smoothstep(0.000, 0.260, edgeDist);
    baseTex.rgb = mix(baseTex.rgb, deepSoil, edgeWeight * 0.32 * intensity * cardAlpha);

    float mossNoise = fbm(uv * vec2(9.0, 13.0) + vec2(time * 0.010, time * 0.006));

    float moss = smoothstep(0.58, 0.86, mossNoise) * smoothstep(0.12, 0.95, radial) * cardAlpha * intensity;
    baseTex.rgb = mix(baseTex.rgb, mossShadow, moss * 0.24);

    float cracksA = crackNetwork(uv * 7.0, time * 0.20);
    float cracksB = crackNetwork(uv * 13.0 + vec2(4.2, 1.7), time * 0.15) * 0.48;
    float cracks = saturate1(cracksA + cracksB);

    cracks *= smoothstep(0.05, 0.40, radial);
    cracks *= cardAlpha;

    float crackPulse = 0.80 + 0.20 * sin(time * 2.2 + fbm(uv * 5.0) * 6.0);
    float livingCracks = cracks * crackPulse * intensity;

    vec3 crackDark = vec3(0.040, 0.027, 0.014);
    vec3 mineralGold = vec3(0.95, 0.62, 0.21);

    baseTex.rgb = mix(baseTex.rgb, crackDark, livingCracks * 0.68);

    float crackGleam = livingCracks * smoothstep(0.54, 0.95, fbm(uv * 24.0 + vec2(time * 0.08, -time * 0.05)));
    baseTex.rgb += crackGleam * mineralGold * 0.20;

    float plateHighlight = smoothstep(0.15, 0.72, cracks) * (1.0 - smoothstep(0.70, 1.00, cracks)) * cardAlpha * intensity;
    baseTex.rgb += plateHighlight * vec3(0.16, 0.12, 0.070) * 0.20;

    float veins = mineralVeins(uv, time, tectonicScale) * cardAlpha * intensity;
    float veinMask = smoothstep(0.22, 0.98, fbm(uv * 3.0 + vec2(1.7, 8.2)));
    veins *= veinMask;

    vec3 quartz = vec3(0.88, 0.80, 0.62);
    vec3 jade = vec3(0.16, 0.62, 0.38);

    baseTex.rgb += quartz * pow(veins, 1.45) * 0.25;
    baseTex.rgb += jade * pow(veins, 2.20) * 0.18;

    float facets = crystalFacetField(uv, time, tectonicScale) * cardAlpha * intensity;
    baseTex.rgb += facets * vec3(0.34, 0.54, 0.38) * 0.18;
    baseTex.rgb += pow(facets, 2.0) * vec3(0.80, 0.70, 0.45) * 0.12;

    vec2 center = uv - 0.5;
    float r = length(center);
    float ang = atan(center.y, center.x);

    float ringWarp = fbm(vec2(ang * 3.0, r * 14.0 - time * 0.25));

    float ringA = 1.0 - smoothstep(
        0.012,
        0.028,
        abs(r - (0.165 + 0.010 * sin(time * 0.8 + ringWarp * 4.0)))
    );

    float ringB = 1.0 - smoothstep(
        0.010,
        0.024,
        abs(r - (0.285 + 0.012 * sin(time * 0.6 + ringWarp * 5.0)))
    );

    float sigilSpokes = 0.5 + 0.5 * cos(ang * 8.0 + ringWarp * 2.0);
    sigilSpokes = smoothstep(0.86, 0.97, sigilSpokes);

    float sigil = (ringA * 0.72 + ringB * 0.48) * (0.58 + sigilSpokes * 0.42) * (1.0 - smoothstep(0.00, 0.43, r)) * intensity * cardAlpha;

    float sigilPulse = 0.72 + 0.28 * sin(time * 2.8 + ringWarp * 4.0);

    baseTex.rgb += sigil * sigilPulse * vec3(0.55, 0.42, 0.20) * 0.24;
    baseTex.rgb += pow(sigil, 2.0) * vec3(0.95, 0.72, 0.32) * 0.20;

    float chipNoise = fbm(uv * 36.0 + vec2(time * 0.005, -time * 0.006));

    float edgeChips = edgeWeight * smoothstep(0.50, 0.86, chipNoise) * cardAlpha * intensity;
    baseTex.rgb = mix(baseTex.rgb, vec3(0.055, 0.040, 0.026), edgeChips * 0.38);

    float edgeMineral = edgeWeight * smoothstep(0.76, 0.98, ridgedFbm(uv * 22.0 + vec2(time * 0.03, -time * 0.02))) * cardAlpha * intensity;
    baseTex.rgb += edgeMineral * vec3(0.44, 0.32, 0.13) * 0.20;

    float erodedEdge = smoothstep(-0.012, 0.028 + 0.015 * chipNoise, edgeDist);
    baseTex.a *= mix(1.0, erodedEdge, 0.12 * intensity);

    float dust = 0.0;
    dust += dustMotes(uv + vec2(0.00, 0.00), time, intensity) * 0.70;
    dust += dustMotes(uv + vec2(0.17, 0.09), time * 0.86, intensity) * 0.38;
    dust += dustMotes(uv + vec2(-0.11, 0.15), time * 1.13, intensity) * 0.24;

    dust *= cardAlpha;
    dust *= smoothstep(0.10, 0.95, radial);

    baseTex.rgb += dust * vec3(0.78, 0.58, 0.31) * 0.20;
    baseTex.a = max(baseTex.a, dust * 0.08 * intensity);

    float weight = 0.96 + 0.04 * sin(time * 0.9 + coarseStone * 4.0);
    baseTex.rgb *= weight;

    float luma = dot(baseTex.rgb, vec3(0.299, 0.587, 0.114));
    baseTex.rgb = mix(baseTex.rgb, vec3(luma), 0.10 * intensity);

    return vec4(saturate3(baseTex.rgb), saturate1(baseTex.a));
}

vec4 effect(vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec2 uv = local_uv_from_texture_coords(texture_coords);
    float anim_time = time;
    if (earth.g > 0.0 || earth.g < 0.0) {
        anim_time = earth.y + earth.x * 0.03125;
    }

    float intensity = 0.92;
    float tectonicScale = 0.72;

    vec2 displacement = earthDisplacement(uv, anim_time, intensity, tectonicScale);

    vec4 cardTexA = Texel(texture, texture_coords_from_local_uv(uv + displacement));
    vec4 cardTexB = Texel(texture, texture_coords_from_local_uv(uv + displacement * 0.55 + vec2(0.0010, -0.0006) * intensity));

    vec4 cardTex = vec4(cardTexB.r, cardTexA.g, cardTexA.b, cardTexA.a);

    vec4 tex = earthEdition(cardTex, uv, anim_time, intensity, tectonicScale);

    return dissolve_mask(tex * colour, texture_coords, uv);
}

#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 vertex_position) {
    if (hovering <= 0.0) {
        return transform_projection * vertex_position;
    }

    float mid_dist = length(vertex_position.xy - 0.5 * love_ScreenSize.xy) / length(love_ScreenSize.xy);
    vec2 mouse_offset = (vertex_position.xy - mouse_screen_pos.xy) / screen_scale;
    float scale = 0.2 * (-0.03 - 0.3 * max(0.0, 0.3 - mid_dist)) * hovering * (length(mouse_offset) * length(mouse_offset)) / (2.0 - mid_dist);

    return transform_projection * vertex_position + vec4(0.0, 0.0, 0.0, scale);
}
#endif
