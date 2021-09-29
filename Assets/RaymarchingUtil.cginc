#define repeat(x, span) (mod(x, span) - 0.5 * span)

// シーン全体の衝突判定(宣言)
float scene(float3 p);

// 偏微分から法線を計算します
float3 calcNormal(float3 p)
{
    float eps = 0.001;
    
    return normalize(float3(
        scene(p + float3(eps, 0.0, 0.0)) - scene(p + float3(-eps, 0.0, 0.0)),
        scene(p + float3(0.0, eps, 0.0)) - scene(p + float3(0.0, -eps, 0.0)),
        scene(p + float3(0.0, 0.0, eps)) - scene(p + float3(0.0, 0.0, -eps))
    ));
}

float calcAmbientOcclusion(float3 pos, float3 normal)
{
    float occ = 0.0;
    float sca = 1.0;
    for (int i = 1; i <= 3; i++)
    {
        float h = 0.01 + 0.12 * float(i) / 4.0;
        float d = scene(pos + h * normal).x;
        occ += (h - d) * sca;
        sca *= 0.95;
        if (occ > 0.35) break;
    }
    return saturate(1.0 - 3.0 * occ) * (0.5 + 0.5 * normal.y);
}

// ソフトシャドウ
float calcSoftShadow(in float3 rayOrigin, in float3 lightDir)
{
    float res = 1.0;
    float distance = 0;
    float ph = 1e10; 
    
    for(int i = 0; i < 32; i++)
    {
        const float d = scene(rayOrigin + lightDir * distance);

        const float y = d * d / (2.0 * ph);
        const float root_d2y2 = sqrt(d * d - y * y);
        res = min(res, 10.0 * root_d2y2 / max(0.0, distance - y));
        ph = d;
        
        distance += d;
        
        if(res < 0.0001 || distance > 2.0)
            break;
    }
    
    res = saturate(res);
    return res * res * (3.0 - 2.0 * res); 
}

// Narkowicz 2015, "ACES Filmic Tone Mapping Curve" 
float3 TonemapACES(float3 x)
{
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return saturate((x * (a * x + b)) / (x * (c * x + d) + e));
}

// Indirect lighting (放射照度)
// Irradiance from "Ditch River" IBL (http://www.hdrlabs.com/sibl/archive.html)
float3 Irradiance_SphericalHarmonics(const float3 n) {
    return max(
          float3( 0.754554516862612,  0.748542953903366,  0.790921515418539)
        + float3(-0.083856548007422,  0.092533500963210,  0.322764661032516) * (n.y)
        + float3( 0.308152705331738,  0.366796330467391,  0.466698181299906) * (n.z)
        + float3(-0.188884931542396, -0.277402551592231, -0.377844212327557) * (n.x)
        , 0.0);
}

// ガンマ補正
float3 LinearToScreen(in float3 color)
{
    const float gamma = 2.2;
    return pow(color, 1 / gamma);
}



float maxcomp(in float3 p ) { return max(p.x,max(p.y,p.z));}

float2 iBox(in float3 ro, in float3 rd, in float3 rad) 
{
    float3 m = 1.0/rd;
    float3 n = m*ro;
    float3 k = abs(m)*rad;
    float3 t1 = -n - k;
    float3 t2 = -n + k;
	return float2( max( max( t1.x, t1.y ), t1.z ),
	             min( min( t2.x, t2.y ), t2.z ) );
}

const float3x3 ma = float3x3( 0.60, 0.00,  0.80,
                      0.00, 1.00,  0.00,
                     -0.80, 0.00,  0.60 );

float3 lerp3(in float3 a, in float3 b, float c)
{
    return float3(
        lerp(a.x, b.x, c),
        lerp(a.y, b.y, c),
        lerp(a.z, b.z, c));
}


float mod(float x, float y)
{
    return x - y * floor(x / y);
}
float2 mod(float2 x, float2 y)
{
    return x - y * floor(x / y);
}
float3 mod(float3 x, float3 y)
{
    return x - y * floor(x / y);
}
float4 mod(float4 x, float4 y)
{
    return x - y * floor(x / y);
}