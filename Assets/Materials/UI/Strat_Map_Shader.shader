Shader "Unlit/Strat_Map_Shader"
{
    Properties
    {
        //_MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

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
                float4 vertex : SV_POSITION;
				float2 pos : TEXCOORD0;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
				o.pos = -0.5 + UNITY_MATRIX_I_V._m03_m13 + v.uv;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
				float2 pos = i.pos;
				fixed4 col = fixed4(0, 0, 0, 1);

				//create grid lines
				const float gridFrequency = 50;
				const float lineWidth = 0.001 * gridFrequency;
				if (frac(pos.x * gridFrequency) < lineWidth || frac(pos.y * gridFrequency) < lineWidth) {
					col.rgb = fixed4(0.01, 0.01, 0.01, 1);
				}

                return col;
            }
            ENDCG
        }
    }
}
