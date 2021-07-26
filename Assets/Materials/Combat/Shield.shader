Shader "Unlit/Shield"
{
	Properties
	{
		_Radius("Radius", float) = 0.5
		_HitNormal("Hit Normal", Vector) = (0, 0, 0, 0)
	}
		SubShader
	{
		Tags {"Queue" = "Transparent" "RenderType" = "Transparent"}
		ZWrite Off
		Cull Off
		Blend SrcAlpha OneMinusSrcAlpha
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			#define MAX_DIST 10
			#define MAX_STEPS 100
			#define EPSILON 0.0001

			struct appdata
			{
				float4 vertex : POSITION;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float3 ro : TEXCOORD0;
				float3 hitPos : TEXCOORD1;
				float4 time : TEXCOORD2;
			};

			float _Radius;
			float4 _HitNormal;

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
				//shape goes here
				return length(p) - _Radius;
			}

			float4 Raymarch(float3 ro, float3 rd) {
				float dO = 0;
				float start = GetDist(ro);
				float dS;
				float3 p = 0;
				[loop]for (half i = 0; i < MAX_STEPS; i++) {
					p = ro + (start + dO) * rd;
					dS = GetDist(p);
					dO += dS;
					if (abs(dS) < EPSILON || dO > MAX_DIST) break;
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

				if (distance >= MAX_DIST) {
					discard;
				}

				fixed4 color = fixed4(0.2, 0.2, 1, 0.01);

				float3 p = hit.xyz;

				//increase alpha at shield boundaries
				const float visibility = 0.3;
				float minAlpha = (1 - pow(abs(dot(normalize(hit.xyz), rd)), 0.5)) * visibility;

				//increase alpha value where shield has been hit
				const float duration = 0.2;
				const float impact = 1;
				float3 hitNor = mul(unity_WorldToObject, _HitNormal.xyz);
				hitNor = normalize(hitNor);
				float hitDot = dot(normalize(hit.xyz), hitNor) * max(0, (_HitNormal.a - _Time.y + duration) / duration);
				color.a = clamp(pow(hitDot, 3), minAlpha, 1);

				return color;
			}
			ENDCG
		}
	}
}
