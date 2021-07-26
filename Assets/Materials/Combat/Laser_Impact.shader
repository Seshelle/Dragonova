Shader "Unlit/Laser_Impact"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
		_StartTime("Start Time", float) = 0
	}
		SubShader
	{
		Tags { "Queue" = "Transparent" "RenderType" = "Transparent" }
		LOD 100
		Cull Off

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			#define MAX_DIST 100
			#define MAX_STEPS 300
			#define EPSILON 0.0001

			struct appdata
			{
				float4 vertex : POSITION;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float3 ro : TEXCOORD1;
				float3 hitPos : TEXCOORD2;
			};

			sampler2D _MainTex;
			float _StartTime;

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.ro = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1));
				o.hitPos = v.vertex;
				return o;
			}

			float GetDist(float3 p) {
				//shape goes here
				return length(p) - _Time.x + _StartTime;
			}

			float4 Raymarch(float3 ro, float3 rd) {
				float dO = 0;
				float dS;
				float3 p = 0;
				[loop]for (int i = 0; i < MAX_STEPS; i++) {
					p = ro + dO * rd;
					dS = GetDist(p);
					dO += dS / 2.;
					if (dS < EPSILON || dO > MAX_DIST) break;
				}
				return float4(p, dO);
			}

			float3 GetNormal(float3 p) {
				float2 e = float2(1e-3, 0);
				float3 n = GetDist(p) - float3(
					GetDist(p - e.xyy),
					GetDist(p - e.yxy),
					GetDist(p - e.yxx)
					);
				return normalize(n);
			}

			fixed4 frag(v2f i) : SV_Target
			{
				float3 ro = i.ro;
				float3 rd = normalize(i.hitPos - ro);

				float4 hit = Raymarch(ro, rd);

				float distance = hit.w;
				fixed4 color = fixed4(0.5, 0.5, 0.5, 1);

				if (distance >= MAX_DIST) {
					discard;
				}

				float3 p = hit.xyz;
				return color;
			}
			ENDCG
		}
	}
}
