Shader "Unlit/Planet_Desert"
{
	Properties
	{
		_MainTex("Texture", Cube) = "white" {}
		_GrassTex("Grass", 2D) = "white" {}
		_ShadowTex("Shadow", 2D) = "Black" {}
		_Radius("Radius", float) = 0.4
		_Scale("Scale", float) = 2
		_SeaLevel("Sea Level", float) = -1
	}
		SubShader
		{
			LOD 100
			CGINCLUDE
				#define MAX_DIST 2
				#define MAX_STEPS 200
				#define FOG 12
				#define SH_STEPS 32
				#define EPSILON 0.00001
				#define BEACH _SeaLevel + 0.0011
				#define GRASS_UV uv * (1500 + gap * 1000 * tex2D(_GrassTex, uv * 10 + _Time.x * 0.1))

				#include "UnityCG.cginc"
				#include "AutoLight.cginc"

				samplerCUBE _MainTex;
				sampler2D _GrassTex;
				sampler2D _CameraDepthTexture;
				sampler2D _ShadowTex;
				float4 _ShadowTex_TexelSize;
				float _Radius;
				float _Scale;
				float _SeaLevel;

				struct appdata
				{
					float4 vertex : POSITION;
				};

				struct v2f
				{
					float4 pos : SV_POSITION;
					float3 ro : TEXCOORD0;
					float3 hitPos : TEXCOORD1;
				};

				v2f vert(appdata v)
				{
					v2f o;
					o.ro = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1));
					o.hitPos = v.vertex;
					o.pos = UnityObjectToClipPos(v.vertex);
					return o;
				}

				float smoothstep(float edge0, float edge1, float x) {
					x = saturate((x - edge0) / (edge1 - edge0));
					return x * x * (3 - 2 * x);
				}

				half2 getSphereUV(const float3 p) {
					half3 octant = sign(p);
					half sum = dot(p, octant);
					half2 octahedron = p / sum;

					return mad(0.5, octahedron.xy, 0.5);
				}

				float groundHeight(const float3 p) {
					const float2 map = texCUBE(_MainTex, p);
					const float lumps = tex2D(_GrassTex, getSphereUV(p) * 20).r * 0.001;
					return (map.r + map.g + lumps) * -_Scale;
				}

				float groundDist(const float3 p) {
					float gap = length(p) - _Radius - groundHeight(p);
					return gap - EPSILON;
				}

				float3 getNormal(const float3 p)
				{
					const float3 eps = float3(0.001, 0.0, 0.0);
					return normalize(float3(
						groundDist(p + eps.xyy) - groundDist(p - eps.xyy),
						groundDist(p + eps.yxy) - groundDist(p - eps.yxy),
						groundDist(p + eps.yyx) - groundDist(p - eps.yyx)));
				}

				float getHeight(const float3 p) {
					const float2 map = texCUBE(_MainTex, p);
					const half2 uv = getSphereUV(p);
					const float lumps = tex2D(_GrassTex, uv * 20).r * 0.001;
					return (map.r + map.g + lumps) * -_Scale;
				}

				float getDist(const float3 p) {
					return length(p) - _Radius - getHeight(p);
				}

				float4 raymarch(const float3 ro, const float3 rd) {
					float dO = EPSILON;
					float dS;
					float3 p = 0;
					bool side = getDist(p) > 0;
					bool oldSide = side;
					float mult = 1;
					[loop]for (half i = 0; i < MAX_STEPS; i++) {
						p = mad(dO, rd, ro);
						dS = getDist(p);
						side = dS > 0;
						if (side != oldSide) mult *= 0.5;
						dO = mad(mult, dS, dO);
						if (abs(dS) < EPSILON || dO > MAX_DIST) break;
						oldSide = side;
					}
					return float4(p, dO);
				}

				half raycast(const float3 ro, const float3 rd) {
					//returns 0 when ray is blocked, 1 otherwise
					half dO = EPSILON;
					half dS;
					half3 p = 0;
					[loop]for (half i = 0; i < MAX_STEPS; i++) {
						p = mad(dO, rd, ro);
						dS = getDist(p);
						if (dS < EPSILON) return 0;
						dO += dS;
						if (dO > MAX_DIST) return 1;
					}
					return 1;
				}

				float2 sphereIntersect(float3 ro, float3 rd, float r) {
					const float b = dot(ro, rd);
					const float c = -r * r + dot(ro, ro);
					float h = b * b - c;
					if (h < 0) return -1; // no intersection
					h = sqrt(h);
					return float2(-b - h, -b + h);
				}

				float2 closeSphereHit(float3 ro, float3 rd, float r) {
					const float b = dot(ro, rd);
					const float c = -r * r + dot(ro, ro);
					float h = b * b - c;
					//if (h < 0) return -1; // no intersection
					h = sign(c) * sqrt(h);
					return float2(-b - h, -b + h);
				}

				bool sphereHit(float3 ro, float3 rd, float r) {
					if (length(ro) <= r) return true;
					const float b = dot(ro, rd);
					const float c = -r * r + dot(ro, ro);
					float h = b * b - c;
					return h >= 0 && dot(rd, -normalize(ro)) > 0;
				}

				half calcSoftshadow(const float3 ro, const float3 rd)
				{
					half res = 1;
					half t = 0.001;
					half ph = 1e10;

					[loop]for (half i = 0; i < SH_STEPS; i++)
					{
						half h = groundDist(mad(t, rd, ro));
						half y = h * h / (2 * ph);
						half d = length(half2(h, y));
						res = min(res, 5 * d / max(0, t - y));
						ph = h;

						t += h;

						if (res < EPSILON || t>MAX_DIST) break;

					}
					//res = saturate(res);
					return res * res*(3.0 - 2.0*res);
				}

				half3 atmoColor(float horizon, float sunDot) {
					const half3 skyColor = half3(0.001, 0.01, 1);
					const half3 sunsetColor = half3(0.1, 0.002, 0);
					half3 finalColor = lerp(skyColor, sunsetColor, smoothstep(0.05, 0.2, horizon));
					finalColor = lerp(finalColor, 0, smoothstep(0, 0.3, horizon));

					return finalColor;
				}

				half4 addClouds(float3 ro, float3 rd, float dist, float2 air) {
					float density = 0;
					float3 p;
					const float steps = 50;
					const float minCloud = 0.4;
					const float cloudAltitude = 0.485;

					//const float2 lower = max(0, closeSphereHit(ro, rd, cloudAltitude - 0.01));
					float start = max(0, air.x);
					//if (length(ro) < cloudAltitude) start = lower.x;
					//if (dist < start) return 0;
					//float end = min(dist, air.y);
					float end = min(dist, air.y);
					//if (dist < air.y) end = min(dist, lower.x);
					const float stepSize = (end - start) / steps;

					[loop]for (float i = 0; i < steps; i++) {
						p = ro + rd * (start + i * stepSize);
						const float altitude = length(p);
						const float perturb = texCUBE(_MainTex, p.yzx).r * 2;
						//if (altitude < cloudAltitude + perturb || altitude > _Radius - perturb) continue;
						const float mult = saturate(1 - abs(altitude - cloudAltitude) * 50 - perturb);
						density += smoothstep(minCloud, 1, texCUBE(_MainTex, p.zxy).r) * stepSize * mult;
					}

					//const half nightSide = smoothstep(-0.5, 0.5, dot(float3(-1, 0, 0), ro + rd * air.y));
					const half3 color = half3(1, 1, 1);// * nightSide;

					return half4(color, 1 - exp(-density * 500));
				}

				half4 collectColor(float3 ro, float3 rd, float3 ld, float dist, float sunDot, float2 air) {
					//if (air.x > air.y || dist < air.x) return 0;
					if (dist < air.x) return 0;
					//half4 clouds = addClouds(ro, rd, dist);
					//set end point of ray to the planet if it hit the planet
					air.y = min(air.y, dist);
					//the start of ray is where it enters the atmosphere
					air.x = max(air.x, 0);

					half horizon = sphereIntersect(ro, ld, _Radius - _Scale * 0.33).y;
					//density for how much atmosphere it passes through
					half div = 2 - sunDot;
					if (dist <= MAX_DIST) div = 3;
					half density = (air.y - air.x) * FOG / div;

					const half4 color = half4(atmoColor(horizon, sunDot) * pow(density, 3), density);

					return saturate(color);
				}

				half3 terrainColor(float3 p, const float3 lig, const float dist) {
					half3 color = 0;
					const float gap = groundDist(p);
					half2 uv = getSphereUV(p);
					half grassLength = tex2D(_GrassTex, GRASS_UV).r;
					half3 albedo = half3(0.001, grassLength * 0.04 + 0.01, 0.0001);
					const float3 nor = getNormal(p);

					float3 worldPos = mul(unity_ObjectToWorld, p);
					float depth = distance(_WorldSpaceCameraPos, worldPos);

					float atten = 1;
					if (depth < _LightSplitsFar.w) {
						//get shadow depth from the correct shadow cascade
						float4 near = float4 (depth >= _LightSplitsNear);
						float4 far = float4 (depth < _LightSplitsFar);
						float4 weights = near * far;

						float3 shadowCoord0 = mul(unity_WorldToShadow[0], float4(worldPos, 1)).xyz;
						float3 shadowCoord1 = mul(unity_WorldToShadow[1], float4(worldPos, 1)).xyz;
						float3 shadowCoord2 = mul(unity_WorldToShadow[2], float4(worldPos, 1)).xyz;
						float3 shadowCoord3 = mul(unity_WorldToShadow[3], float4(worldPos, 1)).xyz;

						float3 coord =
							shadowCoord0 * weights.x +
							shadowCoord1 * weights.y +
							shadowCoord2 * weights.z +
							shadowCoord3 * weights.w;

						atten = tex2D(_ShadowTex, coord.xy).r <= coord.z;

						float blurSize = 2;
						atten = 0;
						for (int i = -blurSize; i <= blurSize; i++) {
							for (int j = -blurSize; j <= blurSize; j++) {
								float2 uv = coord.xy + float2(i * _ShadowTex_TexelSize.x, j * _ShadowTex_TexelSize.y);
								atten += tex2D(_ShadowTex, uv).r <= coord.z;
							}
						}

						atten /= (blurSize * 2 + 1) * (blurSize * 2 + 1);
					}

					//compare sphere normal to terrain normal to determine slope
					const float3 flatNor = normalize(p);

					float dots = tex2D(_GrassTex, uv * 1500) * 0.5 + 0.5;
					albedo = half3(0.07, 0.05, 0.04) * dots;

					// ambient light
					half3 atmo = atmoColor(dot(flatNor, lig) + 0.3, dot(nor, lig));
					half night = smoothstep(-0.5, 0.1, dot(flatNor, lig));
					const half3 ambColor = lerp(atmo * night, half3(0.06, 0.32, 0.4), 0.25);

					// key light
					const float dif = saturate(dot(nor, lig)) * calcSoftshadow(p, lig);

					color.rgb += mad(dif, atten, 0.02) + ambColor;
					color.rgb *= albedo;
					return color;
				}

				float4 rmDist(const float3 ro, const float3 rd, const float max_hit) {
					float dO = EPSILON;
					float dS;
					float3 p = 0;
					bool side = getDist(p) > 0;
					bool oldSide = side;
					float mult = 1;
					[loop]for (half i = 0; i < MAX_STEPS; i++) {
						//p = dO * rd + ro;
						p = mad(dO, rd, ro);
						float4 clipPos = UnityObjectToClipPos(p);
						float hitDepth = clipPos.z / clipPos.w;
						if (hitDepth < max_hit) return float4(p, -dO * hitDepth / max_hit);
						dS = getDist(p);
						if (abs(dS) < EPSILON * i * 0.05 || dO > MAX_DIST) break;
						side = dS > 0;
						if (side != oldSide) mult *= 0.5;
						//dO += dS * mult;
						dO = mad(mult, dS, dO);
						oldSide = side;
					}
					return float4(p, dO);
				}

				half4 addOceanAtmo(float3 ro, float3 rd, float3 p, float dist, float3 lig, float2 air) {
					return collectColor(ro, rd, lig, dist, dot(rd, lig), air);
				}
			ENDCG

			Pass
			{
				Tags {"Queue" = "Transparent"}
				ZTest Off
				Cull Off
				Blend SrcAlpha OneMinusSrcAlpha
				CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag

				struct shadowInput {
					SHADOW_COORDS(0)
				};

				fixed4 frag(v2f i, out float outDepth : SV_Depth) : SV_Target
				{
					const float3 ro = i.ro;
					const float3 rd = normalize(i.hitPos - ro);

					//calculate where the ray enters and exits the atmosphere
					const float2 air = sphereIntersect(ro, rd, 0.5);
					//if it missed the atmosphere it also missed the planet and can be ignored
					clip(air.y);

					const float2 screenUV = float2(i.pos.x / _ScreenParams.x, i.pos.y / _ScreenParams.y);
					const float depth = tex2D(_CameraDepthTexture, screenUV).r - EPSILON;

					const float4 hit = rmDist(ro, rd, depth);
					const float3 p = hit.xyz;
					const float3 lig = normalize(mul(unity_WorldToObject, float3(-1, 0, 0)));
					const half sunDot = dot(rd, lig);
					half4 color = addOceanAtmo(ro, rd, p, min(abs(hit.w), air.y), lig, air);

					float4 clipPos = UnityObjectToClipPos(hit.xyz);
					outDepth = clipPos.z / clipPos.w;
				#if !defined(UNITY_REVERSED_Z)
					outDepth = outDepth * 0.5 + 0.5;
				#endif

					if (hit.w < MAX_DIST && hit.w >= 0) {
						//hit the planet's terrain
						color = lerp(half4(terrainColor(p, lig, hit.w), 1), color, color.a);
						color.a = 1;
					}
					else {
						//only hit the atmosphere
						outDepth = depth;
					}

					half4 clouds = addClouds(ro, rd, abs(hit.w), air);
					color.rgb = pow(color.rgb, 0.4545);
					color.rgb = lerp(color.rgb, clouds.rgb, clouds.a);
					color.a = saturate(clouds.a + color.a);
					return color;
				}
				ENDCG
			}
		}
}
