Shader "Unlit/02_UVGradient"
{
    Properties
    {
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        CULL Off

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = float4(v.vertex.xy * 2.0, 0.5, 1.0);
                o.uv = v.uv;
                // Direct3DのようなUVの上下が反転したPFを考慮
                #if UNITY_UV_STARTS_AT_TOP
                o.uv.y = 1 - o.uv.y;
                #endif
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = float4(i.uv, 0.0, 1.0);
                return col;
            }
            ENDCG
        }
    }
}
