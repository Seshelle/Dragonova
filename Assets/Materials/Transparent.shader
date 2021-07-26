Shader "Unlit/Transparent"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
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
				float4 time : TEXCOORD3;
			};

			sampler2D _MainTex;

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
				return length(p);
			}

			float4 Raymarch(float3 ro, float3 rd) {
				float dO = 0;
				float dS;
				float3 p = 0;
				[loop]for (half i = 0; i < MAX_STEPS; i++) {
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

			float calculateObstruction(float3 pos, float3 lpos)
			{
				float3 dir = normalize(lpos - pos);
				float rad = 0.6;
				float depth = 0.05;
				float dist;
				const float ldist = length(lpos - pos);
				float obs = 0.;
				[loop]for (half i = 0; i < 128; i++) {
					dist = GetDist(pos + depth * dir);
					obs = max(0.5 - dist * ldist / (rad * depth * 2), obs);
					if (obs > 1) return 1;
					depth += max(dist / 2., rad*depth / ldist);
					if (depth >= ldist) {
						break;
					}
				}
				return obs;
			}

			float3 phongContribForLight(float3 k_d, float3 k_s, float alpha, float3 p, float3 eye,
				float3 lightPos, float3 lightIntensity) {
				float3 N = GetNormal(p);
				float3 L = normalize(lightPos - p);
				float3 V = normalize(eye - p);
				float3 R = normalize(reflect(-L, N));

				float dotLN = dot(L, N);
				float dotRV = dot(R, V);

				if (dotLN < 0.0) {
					// Light not visible from this point on the surface
					return float3(0, 0, 0);
				}

				if (dotRV < -0.0) {
					// Light reflection in opposite direction as viewer, apply only diffuse
					// component
					return lightIntensity * (k_d * dotLN);
				}

				return lightIntensity * (k_d * dotLN + k_s * pow(dotRV, alpha));
			}

			float3 phongIllumination(float3 albedo, float3 diffuse, float3 specular, float alpha, float3 p, float3 eye) {
				const float3 ambientLight = 0.5 * float3(1.0, 1.0, 1.0);
				float3 color = ambientLight * albedo;

				float3 light1Pos = float3(-12.0, 12.0, 0.0);
				float3 light1Intensity = float3(0.4, 0.4, 0.4);

				float obs = calculateObstruction(p, light1Pos);
				if (obs > EPSILON) specular = float3(0, 0, 0);

				float3 cont = phongContribForLight(diffuse, specular, alpha, p, eye, light1Pos, light1Intensity);
				color += cont * (1. - obs);

				return color;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				return 0.5;
				float3 ro = i.ro;
				float3 rd = normalize(i.hitPos - ro);

				float4 hit = Raymarch(ro, rd);

				float distance = hit.w;
				fixed4 color = fixed4(0.5, 0.5, 0.5, 1);

				if (distance >= MAX_DIST) {
					discard;
				}

				float3 p = hit.xyz;

				float3 albedo = 1;
				float3 diffuse = 1;
				float3 specular = 1;
				float shininess = 300;
				color.rgb = phongIllumination(albedo, diffuse, specular, shininess, p, ro);
				return color;
			}
			ENDCG
		}
	}
}
