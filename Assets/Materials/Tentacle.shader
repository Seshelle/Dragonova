Shader "Unlit/Tentacle"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
		Cull Front

		CGINCLUDE

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
			float3 ro : TEXCOORD1;
			float3 hitPos : TEXCOORD2;
		};

		sampler2D _MainTex;

		v2f vert(appdata v)
		{
			v2f o;
			o.vertex = UnityObjectToClipPos(v.vertex);
			o.ro = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1));
			o.hitPos = v.vertex;
			return o;
		}

		float sphereDist(float3 p, float radius, float3 orig) {
			return length(p - orig) - radius;
		}

		float tailDist(float3 p, float3 a, float3 b, float r) {
			float3 pa = p - a;
			b.y = sin(p.z * 10) / 10;
			float3 ba = b - a;
			float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
			return length(pa - ba * h) - r;
		}

		float GetDist(float3 p) {
			float sphere = sphereDist(p, 0.25, float3(0, 0, 0.25));
			float tail = tailDist(p, float3(0, 0, 0.25), float3(0, 0, -0.45), 0.05);
			return min(sphere, tail);
		}

		float4 Raymarch(float3 ro, float3 rd) {
			float dO = 0;
			float start = GetDist(ro);
			float dS;
			float3 p = 0;
			[loop]for (int i = 0; i < MAX_STEPS; i++) {
				p = ro + (start + dO) * rd;
				dS = GetDist(p);
				dO += dS;
				if (dS < EPSILON || dO > MAX_DIST) break;
			}
			return float4(p, dO);
		}
		ENDCG

        Pass
        {
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag		

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
				float ldist = length(lpos - pos);
				float obs = 0.;
				[loop]for (int i = 0; i < 128; i++) {
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

				float3 light1Pos = normalize(mul(unity_WorldToObject, float3(-1.0, 0, 0)));
				float3 light1Intensity = float3(0.4, 0.4, 0.4);

				float obs = calculateObstruction(p, light1Pos);
				if (obs > EPSILON) specular = float3(0, 0, 0);

				float3 cont = phongContribForLight(diffuse, specular, alpha, p, eye, light1Pos, light1Intensity);
				color += cont * (1. - obs);

				return color;
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

				float3 albedo = float3(0.7, 0.3, 0);
				float3 diffuse = 1;
				float3 specular = 1;
				float shininess = 300;
				color.rgb = phongIllumination(albedo, diffuse, specular, shininess, p, ro);
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
				if (hit.w >= MAX_DIST) {
					discard;
				}
				return 0;
			}
			ENDCG
		}
    }
}
