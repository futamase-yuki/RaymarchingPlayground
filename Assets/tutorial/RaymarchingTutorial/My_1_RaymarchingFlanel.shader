Shader "Unlit/My_1_RaymarchingFresnel"
{
    Properties
    {
        _BallAlbedo ("Ball Albedo", Color) = (1, 0, 0, 1)
        _FloorAlbedoA ("Floor Albedo A", Color) = (0, 0, 0, 1)
        _FloorAlbedoB ("Floor Albedo B", Color) = (1, 1, 1, 1)
        _SkyTopColor ("Sky Top Color", Color) = (1, 1, 1, 1)
        _SkyBottomColor ("Sky Bottom Color", Color) = (1, 1, 1, 1)
        _FresnelReflectance ("Fresnel Reflectance", Float) = 0.5 
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        
        Pass
        {
            Cull Off
            CGPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            
            #include "UnityCG.cginc"
            #include "UnityLightingCommon.cginc"
            #include "Assets/DistanceFunction.cginc"
            #include "Assets/RaymarchingUtil.cginc"
            
            float3 _BallAlbedo;
            float3 _FloorAlbedoA;
            float3 _FloorAlbedoB;
            float3 _SkyTopColor;
            float3 _SkyBottomColor;
            float _FresnelReflectance;
            
            struct appdata
            {
                float4 vertex: POSITION;
                float2 uv: TEXCOORD0;
            };
            
            struct v2f
            {
                float2 uv: TEXCOORD0;
                float4 vertex: SV_POSITION;
            };

            v2f vert(appdata v)
            {
                v2f o;
                
                o.vertex = float4(v.vertex.xy, 0.5, 1.0);

                
                o.uv = v.uv;
                
                // Direct3DのようにUVの上下が反転したプラットフォームを考慮します
                #if UNITY_UV_STARTS_AT_TOP
                    o.uv.y = 1 - o.uv.y;
                #endif
                
                return o;
            }

            // float mod(float x, float y)
            // {
            //     return x - y * floor(x / y);
            // }
            // float2 mod(float2 x, float2 y)
            // {
            //     return x - y * floor(x /  y);
            // }

            float repBall(float3 p, float interval)
            {
                p.x += exp2(_SinTime.y * 2) * 5;
                p.y += 6 * p.x * 0.0001;
                p.z += exp2(_CosTime.y * 2) * 5;
                return sdSphere(float3(repeat(p.x, interval), repeat(p.y, interval), repeat(p.z, interval)), 1.);
            }
            
            float dBall(float3 p)
            {
                return repBall(p, 10);
                p.xz = repeat(p.xz, 10);
                return sdSphere(p - float3(0, 1, 0), 1);
            }
            
            float dFloor(float3 p)
            {
                return sdPlane(p, float3(0, 1, 0), 5);
            }

            float barDist(float2 p, float width)
            {
                return length(
                    max(
                        abs(repeat(p, 10)) - width,
                        0.0)
                        );
            }
            float hoge(float3 p)
            {
                float barX = barDist(p.yz, 0.5);
                float barY = barDist(p.xz, 0.5);
                float barZ = barDist(p.xy, 0.5);
                return min(min(barX, barY), barZ);
            }
            
            float scene(float3 p)
            {
                return min(
                    dFloor(p), min(dBall(p), hoge(p))
                        );
            }
            
            // フレネル項のSchlick近似
            float fresnelSchlick(float f0, float cosTheta)
            {
                return f0 + (1.0 - f0) * pow((1.0 - cosTheta), 5.0);
            }
            
            // フレネル項のSpherical Gaussian近似
            // exp2 を使うことでSchlickより高速らしい
            float fresnelSphericalGaussian(float f0, float cosTheta)
            {
                return f0 + (1.0 - f0) * exp2((-5.55473 * cosTheta -6.98316) * cosTheta);
            }

            // それっぽいフレネル項
            float fresnel(float3 viewDir, float3 halfVec)
            {
                float VdotH = saturate(dot(viewDir, halfVec));
                float F0 = saturate(_FresnelReflectance);
                float F = pow(1.0 - VdotH, 5.0);
                F *= (1.0 - F0);
                F += F0;
                return F; 
            }

            float3 render(in float3 normal, in float3 rayOrigin, inout float3 rayDirection, float distance, inout float3 reflectionAttenuation)
            {
                float3 color = float3(0,0,0);
                
                // ライティングのパラメーター
                const float3 light = _WorldSpaceLightPos0;// 平行光源の方向ベクトル
                const float3 ref = reflect(rayDirection, normal);// レイの反射ベクトル
                float f0 = 0;// フレネル反射率F0
                
                // マテリアルのパラメーター
                float3 albedo = float3(1, 1, 1);// アルベド
                float metalness = 0;// メタルネス（金属の度合い）
                
                // ボールのマテリアルを設定
                if (dBall(rayOrigin) < 0.0001)
                {
                    albedo = _BallAlbedo;
                    metalness = 1;
                    f0 = 0.9;
                }

                if(hoge(rayOrigin) < 0.0001)
                {
                    albedo = float3(228.0 / 255., 168. / 255., 38. / 255.);
                    metalness = 0.1;
                    f0 = 0.1;
                }
                
                // 床のマテリアルを設定
                if (dFloor(rayOrigin) < 0.0001)
                {
                    float checker = mod(floor(rayOrigin.x) + floor(rayOrigin.z), 2.0);
                    albedo = lerp(_FloorAlbedoA, _FloorAlbedoB, checker);
                    metalness = 0.1;
                    f0 = 0.1;
                }

                // ライティング計算
                // 拡散反射
                float diffuse = saturate(dot(normal, light)) / UNITY_PI;
                
                // 鏡面反射
                float specular = pow(saturate(dot(reflect(light, normal), rayDirection)), 10.0);

                float ao = calcAmbientOcclusion(rayOrigin, normal); // AO
                float shadow = calcSoftShadow(rayOrigin, light);
                
                // ライティング結果の合成
                // 直接光の拡散反射
                color += albedo * diffuse * shadow * (1 - metalness) * _LightColor0.rgb;
                
                // 直接光の鏡面反射
                color += albedo * specular * shadow * metalness * _LightColor0.rgb;

                // 環境光
                color += albedo * ao * lerp(_SkyBottomColor, _SkyTopColor, 0.3);
                
                // 遠景のフォグ
                const float invFog = exp(-0.012 * distance);
                color = lerp(_SkyBottomColor, color, invFog);

                // 反射の減衰率を更新。シェーダーでは再帰が使えないため、呼び出し側で結果を合成
                reflectionAttenuation *= albedo * fresnelSphericalGaussian(f0, dot(ref, normal)) * metalness;
                // reflectionAttenuation *= albedo * fresnel(rayDirection, normalize(rayDirection + normalize(light))) * invFog;

                rayDirection = ref;

                return color;
            }

            float3 raymarching(inout float3 origin, inout float3 ray, out bool hit, inout float3 reflectionAttenuation)
            {
                // レイマーチング
                hit = false;
                float t = 0.0;// レイの進んだ距離
                float3 p = origin;// レイの先端の座標
                int i = 0;// レイマーチングのループカウンター
                
                for (i = 0; i < 128; i++)
                {
                    float d = scene(p);// 最短距離を計算します
                    
                    // 最短距離を0に近似できるなら、オブジェクトに衝突したとみなして、ループを抜けます
                    if (d < 0.00005)
                    {
                        hit = true;
                        break;
                    }
                    
                    t += d;// 最短距離だけレイを進めます
                    p = origin + ray * t;// レイの先端の座標を更新します
                }
                
                if (hit)
                {
                    float3 normal = calcNormal(p);// 法線
                    float3 col = render(normal, p, ray, t, reflectionAttenuation);
                    // レイを反射用に更新
                    // 少しずらさないとレイが進まない
                    origin = p + 0.001 * normal;

                    return col;
                } 
                
                // 空
                return lerp(_SkyBottomColor, _SkyTopColor, ray.y);
            }

            // カメラ位置からワールド空間のレイを取得
            float3 GetRay(in float2 uv, in float3 cameraOrigin)
            {
                // カメラ行列からレイを生成
                float4 clipRay = float4(uv, 1, 1);// クリップ空間のレイ
                
                // ビュー空間のレイ
                float3 viewRay = normalize(mul(unity_CameraInvProjection, clipRay).xyz);

                // ワールド空間のレイ
                return mul(transpose((float3x3)UNITY_MATRIX_V), viewRay);
            }

            float4 frag(v2f input): SV_Target
            {
                float3 col = float3(0.0, 0.0, 0.0);
                
                // UVを -1～1 の範囲に変換
                float2 uv = 2.0 * input.uv - 1.0;
                
                // カメラの位置
                float3 cameraOrigin = _WorldSpaceCameraPos;
                float3 ray = GetRay(uv, cameraOrigin);

                bool hit = false;// オブジェクトに衝突したかどうか
                float3 reflectionAttenuation = float3(1, 1, 1);// 反射の減衰率

                // レイは最大3回まで反射
                for (int i = 0; i < 3; i++)
                {
                    col += reflectionAttenuation * raymarching(cameraOrigin, ray, hit, reflectionAttenuation);

                    if (!hit) 
                    {
                        break;
                    }
                }
                
                // トーンマッピング
                //col = TonemapACES(col * 0.8);
                
                // ガンマ補正
                col = pow(col, 1 / 2.2);
                
                return float4(col, 1);
            }
            ENDCG
        }
    }
}
