Shader "Unlit/Planet_Depth"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
		_GrassTex("Grass", 2D) = "white" {}
		_ShadowTex("Shadow", 2D) = "Black" {}
		_Radius("Radius", float) = 0.4
		_Scale("Scale", float) = 2
		_SeaLevel("Sea Level", float) = 0.45
		_AtmoRadius("Atmosphere Radius", float) = 0.1
	}
		SubShader
		{
			LOD 100
			CGINCLUDE
				#define MAX_DIST 10
				#define MAX_STEPS 300
				#define WATER_STEPS 128
				#define WAVE_HEIGHT 0.0001
				#define SH_STEPS 64
				#define STMAX 3
				#define EPSILON 0.00001

				#include "UnityCG.cginc"
				#include "AutoLight.cginc"

				sampler2D _MainTex;
				sampler2D _GrassTex;
				sampler2D _CameraDepthTexture;
				sampler2D _ShadowTex;
				float4 _MainTex_ST;
				float _Radius;
				float _Scale;
				float _SeaLevel;
				float _AtmoRadius;

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
					return x * x * x * (x * (x * 6 - 15) + 10);
				}

				half2 getSphereUV(const float3 p) {
					half3 octant = sign(p);
					//half3 octant = half3(p.x >= 0 ? 1 : -1, p.y >= 0 ? 1 : -1, p.z >= 0 ? 1 : -1);

					// Scale the vector so |x| + |y| + |z| = 1 (surface of octahedron).
					half sum = dot(p, octant);
					half3 octahedron = p / sum;

					// "Untuck" the corners using the same reflection across the diagonal as before.
					// (A reflection is its own inverse transformation).
					if (octahedron.z < 0) {
						const half3 absolute = abs(octahedron);
						octahedron.xy = octant.xy * float2(1 - absolute.y, 1 - absolute.x);
					}

					//half2 uv = octahedron.xy * 0.5 + 0.5;
					half2 uv = mad(0.5, octahedron.xy, 0.5);

					return uv;
				}

				half2 difSphereUV(const float3 p) {
					half3 octant = sign(p);
					//half3 octant = half3(p.x >= 0 ? 1 : -1, p.y >= 0 ? 1 : -1, p.z >= 0 ? 1 : -1);

					// Scale the vector so |x| + |y| + |z| = 1 (surface of octahedron).
					half sum = dot(p, octant);
					half3 octahedron = p / sum;

					//half2 uv = 0.6 + 0.5 * octahedron.xy;
					half2 uv = mad(0.5, octahedron.xy, 0.6);

					return uv;
				}

				half3 getColor(float3 p) {
					return tex2Dlod(_MainTex, float4(getSphereUV(p), 0, 0));
				}

				half getHeight(const float3 p) {
					half2 uv = getSphereUV(p);
					half2 map = tex2Dlod(_MainTex, half4(uv, 0, 0)).rg;

					//blend the seams with terrain from another area
					const half blend = max(abs(uv.x - 0.5), abs(uv.y - 0.5));
					half adj = tex2Dlod(_MainTex, half4(difSphereUV(p), 0, 0)).r;
					map.r = lerp(map.r, adj, 2 * blend);

					return (map.r + map.g) * -_Scale;
				}

				half waveHeight(const float3 p) {
					const half depth = (_Radius + _SeaLevel) - getHeight(p);
					const half inWave = cos(depth * 2000 + _Time.z * 0.5) * WAVE_HEIGHT;
					return inWave;
				}

				float getDist(const float3 p) {
					return length(p) - _Radius - getHeight(p);
				}

				float waterDist(const float3 p) {
					return length(p) - _Radius - _SeaLevel - waveHeight(p);
				}

				float4 rmWater(const float3 ro, const float3 rd) {
					float dO = 0;
					float dS;
					float3 p = 0;
					const float under = sign(waterDist(ro));
					[loop]for (half i = 0; i < WATER_STEPS; i++) {
						p = mad(dO, rd, ro);
						dS = waterDist(p);
						//dO += dS * under;
						dO = mad(under, dS, dO);
						if (abs(dS) < EPSILON || dO > MAX_DIST + 10) break;
					}
					return float4(p, dO);
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

				float3 waveNormal(const float3 pos) {
					const float2 e = float2(1.0, -1.0)*0.5773*0.0003;
					return normalize(e.xyy*waterDist(pos + e.xyy) +
						e.yyx*waterDist(pos + e.yyx) +
						e.yxy*waterDist(pos + e.yxy) +
						e.xxx*waterDist(pos + e.xxx));
				}

				float3 getNormal(const float3 pos)
				{
					const float2 e = float2(1.0, -1.0)*0.5773*0.0003;
					return normalize(e.xyy*getDist(pos + e.xyy) +
						e.yyx*getDist(pos + e.yyx) +
						e.yxy*getDist(pos + e.yxy) +
						e.xxx*getDist(pos + e.xxx));
				}

				float2 sphereIntersect(float3 ro, float3 rd, float r) {
					float b = dot(ro, rd);
					float c = -r * r + dot(ro, ro);
					float h = b * b - c;
					if (h < 0) return -1; // no intersection
					h = sqrt(h);
					return float2(-b - h, -b + h);
				}

				bool sphereHit(float3 ro, float3 rd, float r) {
					if (length(ro) <= r) return true;
					float b = dot(ro, rd);
					float c = -r * r + dot(ro, ro);
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
						half h = getDist(mad(t, rd, ro));
						half y = h * h / (2 * ph);
						//float d = sqrt(h*h - y * y);
						half d = mad(0.5, min(h, y), max(h, y));
						//float d = length(float2(h, y));
						//res = min(res, 10 * d / max(0, t - y));
						res = min(res, 10 * d / saturate(t - y));
						ph = h;

						t += h;

						if (res < EPSILON || t>STMAX) break;

					}
					res = saturate(res);
					return res * res*(3.0 - 2.0*res);
				}

				/*float calcAO(float3 pos, float3 nor)
				{
					float occ = 0.0;
					float sca = 1.0;
					for (int i = 0; i < 5; i++)
					{
						float h = 0.001 + 0.15*float(i) / 4.0;
						float d = getDist(pos + h * nor);
						occ += (h - d)*sca;
						sca *= 0.95;
					}
					return saturate(1.0 - 1.5*occ);
				}*/

				half3 atmoColor(float horizon, float sunDot) {
					const half3 skyColor = half3(0.001, 0.01, 1);
					half3 sunsetColor = half3(0.1, 0.002, 0);
					half3 finalColor = lerp(skyColor, sunsetColor, smoothstep(0.1, 0.2, horizon));
					finalColor = lerp(finalColor, 0, smoothstep(0, 0.3, horizon));

					return finalColor;
				}

				half4 collectColor(float3 ro, float3 rd, float3 ld, float dist, float sunDot, float2 ray_length) {
					if (ray_length.x > ray_length.y || dist < ray_length.x) return 0;
					//set end point of ray to the planet if it hit the planet
					ray_length.y = min(ray_length.y, dist);
					//the start of ray is where it enters the atmosphere
					ray_length.x = max(ray_length.x, 0);

					float3 enter = ro + rd * ray_length.x;
					half horizon = sphereIntersect(ro, ld, _Radius - _Scale * 0.25).y;
					//density for how much atmosphere it passes through
					half div = 2 - sunDot;
					if (dist <= MAX_DIST) div = 3;
					half density = (15 / div) * (ray_length.y - ray_length.x);
					//return atmoColor(horizon, sunDot) * pow(density, 4);
					density *= smoothstep(-0.5, 0.1, dot(normalize(enter), ld));
					density = max(density, 0);
					return half4(atmoColor(horizon, sunDot), pow(density, 4));
				}

				half3 terrainColor(const float3 p, const float3 lig, const float dist) {
					half3 color = 0;
					//half3 albedo = half3(0.0001, 0.05, 0);
					half2 uv = getSphereUV(p) * 3000;
					//
					//half3 albedo = pow(tex2Dlod(_GrassTex, half4(uv, 0, (dist + 0.01) * 250)), rcp(0.4545));
					half3 albedo = pow(tex2D(_GrassTex, uv), rcp(0.4545));
					const float3 nor = getNormal(p);

					float3 worldPos = mul(unity_ObjectToWorld, p);
					float depth = distance(_WorldSpaceCameraPos, worldPos);
					float4 near = float4 (depth >= _LightSplitsNear);				
					float4 far = float4 (depth < _LightSplitsFar);
					float4 weights = near * far;

					float3 shadowCoord0 = mul(unity_WorldToShadow[0], float4(worldPos, 1.)).xyz;
					float3 shadowCoord1 = mul(unity_WorldToShadow[1], float4(worldPos, 1.)).xyz;
					float3 shadowCoord2 = mul(unity_WorldToShadow[2], float4(worldPos, 1.)).xyz;
					float3 shadowCoord3 = mul(unity_WorldToShadow[3], float4(worldPos, 1.)).xyz;

					float3 coord =									// A smart way to avoid branching. Calculating the final shadow texture uv coordinates per fragment
						shadowCoord0 * weights.x +					// case: Cascaded one
						shadowCoord1 * weights.y +					// case: Cascaded two
						shadowCoord2 * weights.z +					// case: Cascaded three
						shadowCoord3 * weights.w;					// case: Cascaded four

					float atten = tex2D(_ShadowTex, coord.xy).r;	// We don't need to turn it in linear space since Coord.z is also in log based zbuffer
					atten = atten > coord.z;

					/*float4 shadow = mul(unity_WorldToShadow[0], float4(worldPos, 1.0));
					float atten = abs(ceil(tex2D(_ShadowTex, shadow.xy).r) - 1);*/

					//compare sphere normal to land normal to determine slope
					const float3 flatNor = normalize(p);
					const float slope = dot(nor, flatNor);
					const half3 slopeCol = half3(0.015, 0.0015, 0.001);
					albedo = lerp(albedo, slopeCol, saturate(mad(-2.5, slope, 2.5)));

					float beach = _Radius + _SeaLevel + 0.002 - length(p);
					beach = saturate(beach * 1000);
					albedo = lerp(albedo, half3(0.07, 0.05, 0.04), beach);

					// key light
					const float dif = saturate(dot(nor, lig)) * calcSoftshadow(p, lig);
					color.rgb += 2 * albedo * dif * atten;

					// ambient light
					//float occ = calcAO(p, nor);
					half3 atmo = atmoColor(dot(flatNor, lig) + 0.3, dot(nor, lig));
					half night = smoothstep(-0.5, 0.1, dot(flatNor, lig));
					const half3 ambColor = lerp(atmo * night, half3(0.06, 0.32, 0.4), 0.1);
					color.rgb += albedo * ambColor; //* occ;
					return color;
				}

				half4 oceanColor(const float3 ro, const float3 rd, const float3 lig, const float4 hit,
					const float4 oceanHit, const bool underwater, const float oceanDepth) {
					//const float shoreDepth = length(oceanHit.xyz) - getHeight(oceanHit.xyz);
					half4 color = 0;
					if (oceanDepth > 0) {
						float3 surfNor = normalize(oceanHit.xyz);
						//Water is more opaque the deeper it is, and darker on the night side of the planet
						const half3 deepWater = half3(0.0001, 0.001, 0.04);
						const half3 shallowWater = half3(0.0001, 0.03, 0.02);
						const half oceanEffect = clamp(1 - exp(-oceanDepth * 300), 0.75, 1);
						const half3 waterCol = lerp(shallowWater, deepWater, oceanEffect);
						const half nightSide = smoothstep(-0.1, 0, dot(lig, surfNor));
						if (!underwater) {
							color.rgb = waterCol * (nightSide + 0.05);
						}

						//can see ocean surface
						if (hit.w > oceanDepth) {
							const float3 waveNor = waveNormal(oceanHit.xyz);
							//ambient skycolor
							const half fre = pow(saturate(1 + dot(rd, waveNor)), 4);
							const half3 ref = dot(surfNor, waveNor);
							color.rgb += half3(0.0075, 0.05, 0.5) * nightSide * fre * smoothstep(0, 1, ref);
							//specular
							if (!underwater) {
								const float3 hal = normalize(lig - rd);
								color.rgb += 3 * pow(saturate(dot(hal, waveNor)), 64) * nightSide;
							}
						}
						if (underwater) {
							color.rgb = lerp(color.rgb, waterCol, oceanEffect);
							half nightNor = nightSide;
							if (hit.w < MAX_DIST) nightNor = smoothstep(-0.1, 0, dot(lig, normalize(hit.xyz)));
							color.rgb *= nightNor + 0.05;
						}
						return half4(color.rgb, oceanEffect);
					}
					return color;
				}

				float4 rmDist(const float3 ro, const float3 rd, const float max) {
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
						if (hitDepth < max) return float4(p, -dO * (hitDepth / max));
						dS = getDist(p);
						if (abs(dS) < EPSILON * i * 0.01 || dO > MAX_DIST) break;
						side = dS > 0;
						if (side != oldSide) mult *= 0.5;
						//dO += dS * mult;
						dO = mad(mult, dS, dO);
						oldSide = side;
					}
					return float4(p, dO);
				}

				half4 addOceanAtmo(float3 ro, float3 rd, float3 p, float dist, float3 lig, float2 air) {
					half4 color = 0;
					float oceanDepth = -1;
					if (sphereHit(ro, rd, _Radius + _SeaLevel + WAVE_HEIGHT)) {
						const float4 oceanHit = rmWater(ro, rd);
						const bool underwater = waterDist(ro) < 0;
						oceanDepth = dist - oceanHit.w;
						if (underwater) {
							oceanDepth = min(dist, oceanHit.w);
						}

						half4 ocean = oceanColor(ro, rd, lig, float4(p, dist), oceanHit, underwater, oceanDepth);
						color = ocean;
					}

					if (oceanDepth <= 0) {
						half4 atmo = collectColor(ro, rd, lig, dist, dot(rd, lig), air);
						color = atmo;
					}
					return color;
				}
			ENDCG

			Pass
			{
				Tags {"Queue" = "Opaque"}
				ZTest On
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
					const float2 air = sphereIntersect(ro, rd, _Radius + _AtmoRadius);
					//if it missed the atmosphere it also missed the planet and can be ignored
					clip(air.y);

					float2 screenUV = float2(i.pos.x / _ScreenParams.x, i.pos.y / _ScreenParams.y);
					float depth = tex2D(_CameraDepthTexture, screenUV).r;
					if (depth <= 0) depth = -100;

					//const float4 hit = rmDist(ro, rd, depth);
					const float4 hit = raymarch(ro, rd);
					const float3 p = hit.xyz;
					half4 color = half4(0, 0, 0, 1);
					const float3 lig = normalize(mul(unity_WorldToObject, float3(-1.0, 0, 0)));
					const half sunDot = dot(rd, lig);
					float maxBlend = 1000;

					float4 clipPos = UnityObjectToClipPos(hit.xyz);
					outDepth = clipPos.z / clipPos.w;
				#if !defined(UNITY_REVERSED_Z)
					outDepth = outDepth * 0.5 + 0.5;
				#endif

					if (hit.w < 0) {
						//recalculate distance
						float dist = -hit.w;

						color = addOceanAtmo(ro, rd, p, dist, lig, air);

						color.rgb = pow(color.rgb, 0.4545);
						//color.a = saturate(color.a);
						return color;
					}
					else if (hit.w < MAX_DIST) {
						maxBlend = 1;
						color.rgb += terrainColor(p, lig, hit.w);

						/*float3 worldPos = mul(unity_ObjectToWorld, hit.xyz);
						float4 shadow = mul(unity_WorldToShadow[0], float4(worldPos, 1.0));
						float atten = tex2D(_ShadowTex, shadow.xy).r;
						color.rgb *= -atten + 1.25;*/
					}

					half4 newColor = addOceanAtmo(ro, rd, p, hit.w, lig, air);
					color.rgb = lerp(color.rgb, newColor.rgb, min(maxBlend, newColor.a));

					color.rgb = pow(color.rgb, 0.4545);
					return color;
				}
				ENDCG
			}

			/*Pass
			{
				Tags { "LightMode" = "ShadowCaster" }
				ZWrite On ZTest Equal

				CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_shadowcaster

				fixed4 frag(v2f i, out float outDepth : SV_Depth) : SV_Target
				{
					const float3 ro = i.ro;
					const float3 rd = normalize(i.hitPos - ro);
					const float4 hit = raymarch(ro, rd);
					float4 clipPos = UnityClipSpaceShadowCasterPos(hit.xyz, hit.xyz);
					clipPos = UnityApplyLinearShadowBias(clipPos);
					//const float4 clipPos = UnityObjectToClipPos(hit.xyz);
					outDepth = clipPos.z / clipPos.w;
					return 0;
				}
				ENDCG
			}*/
		}
}
