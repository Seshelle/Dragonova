Shader "Unlit/Projectile_Laser"
{
	Properties
	{
		
	}
		SubShader
	{
		Tags { "RenderType" = "Opaque" }
		LOD 100
		Cull Front

		CGINCLUDE

		#define MAX_DIST 10
		#define MAX_STEPS 30
		#define EPSILON 0.0001
		#define CORONA 0.05

		struct appdata
		{
			float4 vertex : POSITION;
		};

		struct v2f
		{
			float4 vertex : SV_POSITION;
			float3 ro : TEXCOORD1;
			float3 hitPos : TEXCOORD2;
			float4 time : TEXCOORD3;
		};

		sampler2D _CameraDepthTexture;

		v2f vert(appdata v)
		{
			v2f o;
			o.vertex = UnityObjectToClipPos(v.vertex);
			o.ro = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1));
			o.hitPos = v.vertex;
			o.time = _Time;
			return o;
		}

		float GetDist(float3 p) {
			float3 b = float3(0.04, 0.04, 0.5);
			float3 q = abs(p) - b;
			return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
		}

		float4 Raymarch(float3 ro, float3 rd) {
			float dO = 0;
			float start = GetDist(ro);
			float dS;
			float3 p = 0;
			float leastDistance = MAX_DIST;
			[loop]for (int i = 0; i < MAX_STEPS; i++) {
				p = ro + (start + dO) * rd;
				dS = GetDist(p);
				dO += dS;
				leastDistance = min(dS, leastDistance);
				if (dS < EPSILON || dO > MAX_DIST) break;
			}
			return float4(p, leastDistance);
		}
		ENDCG

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			float smoothstep(float edge0, float edge1, float x) {
				// Scale, and clamp x to 0..1 range
				x = clamp((x - edge0) / (edge1 - edge0), 0.0, 1.0);
				// Evaluate polynomial
				return x * x * x * (x * (x * 6 - 15) + 10);
			}

			fixed4 frag(v2f i) : SV_Target
			{
				float3 ro = i.ro;
				float3 rd = normalize(i.hitPos - ro);

				float4 hit = Raymarch(ro, rd);
				float leastDistance = hit.w;

				if (leastDistance >= CORONA) {
					discard;
				}
				fixed4 color = fixed4(1, 0, 0, 1);
				//as least distance increases, go to white
				float bloom = smoothstep(0, 0.025, leastDistance);
				color.gb = bloom;

				return color;
			}
			ENDCG
		}

		Pass
		{
			Tags { "LightMode" = "ShadowCaster" }
			ZWrite On
			Cull Front
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag_shadow
			#pragma multi_compile_shadowcaster

			#include "UnityCG.cginc"

			fixed4 frag_shadow(v2f i) : SV_Target
			{
				float3 ro = i.ro;
				float3 rd = normalize(i.hitPos - ro);
				float4 hit = Raymarch(ro, rd);
				float leastDistance = hit.w;

				if (leastDistance >= CORONA) {
					discard;
				}
				return 0;
			}
			ENDCG
		}
	}
}
