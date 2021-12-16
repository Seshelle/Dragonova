Shader "Unlit/Planet_Depth"
{
	Properties
	{
		_MainTex("Texture", Cube) = "white" {}
		_GrassTex("Grass", 2D) = "white" {}
		_ShadowTex("Shadow", 2D) = "Black" {}
		_Radius("Radius", float) = 0.4
		_Scale("Scale", float) = 2
		_SeaLevel("Sea Level", float) = 0.45
	}
		SubShader
		{
			LOD 100
			CGINCLUDE
				#define MAX_DIST 2000
				#define MAX_STEPS 200
				#define WATER_STEPS 200
				#define WAVE_HEIGHT 0.0004
				#define OCEAN_OPAQUE 0
				#define FOG 12
				#define SH_STEPS 32
				#define EPSILON 0.00001
				#define BEACH _SeaLevel + 0.0011

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
					o.ro = mul(unity_WorldToObject, float4(UNITY_MATRIX_I_V._m03_m13_m23, 1));
					o.hitPos = v.vertex;
					o.pos = UnityObjectToClipPos(v.vertex);
					return o;
				}

				/*float smoothstep(float edge0, float edge1, float x) {
					x = saturate((x - edge0) / (edge1 - edge0));
					return x * x * x * (x * (x * 6 - 15) + 10);
				}*/

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

				float rough(float p) {
					return tex2D(_GrassTex, getSphereUV(p) * 20).r * 0.001;
				}

				float groundHeight(const float3 p) {
					const float2 map = texCUBE(_MainTex, p);
					const float lumps = tex2D(_GrassTex, getSphereUV(p) * 50).r * 0.0005;
					return (map.r + map.g) * -_Scale;
				}

				float groundDist(const float3 p) {
					float gap = length(p) - _Radius - groundHeight(p);
					return gap - EPSILON;
				}

				float3 getNormal(const float3 p)
				{
					const float3 eps = float3(0.0005, 0.0, 0.0);
					return normalize(float3(
						groundDist(p + eps.xyy) - groundDist(p - eps.xyy),
						groundDist(p + eps.yxy) - groundDist(p - eps.yxy),
						groundDist(p + eps.yyx) - groundDist(p - eps.yyx)));
				}

				float grassLength(const float3 p) {
					const float terra = texCUBE(_MainTex, p).g;
					const float gap = groundDist(p);
					half2 uv = getSphereUV(p);
					uv = uv * (1500 + gap * 1000 * tex2D(_GrassTex, uv * 10 + _Time.x * 0.1));
					const float grass = tex2D(_GrassTex, uv).r;
					return max(0, grass - terra * 1000);
				}

				float getHeight(const float3 p) {
					const float2 map = texCUBE(_MainTex, p);
					const half2 uv = getSphereUV(p);
					const float lumps = tex2D(_GrassTex, uv * 20).r * 0.001;
					const float height = (map.r + map.g) * -_Scale;
					if (height < BEACH) return height;

					float grass = grassLength(p) * 0.0005;

					return max(0, grass - map.g) * _Scale + height;
				}

				half waveHeight(const float3 p) {
					const half depth = groundHeight(p);
					const half inWave = cos(depth * 2000 - _Time.z * 0.4) * WAVE_HEIGHT * (1 + depth * 15);
					half2 uv = getSphereUV(p);
					half noise = tex2D(_GrassTex, uv * 60 + _Time.x * 0.1).r * 0.00002;
					noise += tex2D(_GrassTex, uv * 30 - _Time.x * 0.05).r * 0.00002;
					//noise += tex2D(_GrassTex, uv * 100 - _Time.x * 0.05).r * 0.00001;
					return inWave + noise;
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
						if (abs(dS) < EPSILON * i * dO * 10 || dO > MAX_DIST + 1) break;
					}
					return float4(p, dO);
				}

				float4 raymarch(const float3 ro, const float3 rd) {
					float dO = 0;
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

				float3 waveNormal(const float3 p)
				{
					const float3 eps = float3(0.00005, 0.0, 0.0);
					return normalize(float3(
						waterDist(p + eps.xyy) - waterDist(p - eps.xyy),
						waterDist(p + eps.yxy) - waterDist(p - eps.yxy),
						waterDist(p + eps.yyx) - waterDist(p - eps.yyx)));
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
						half h = groundDist(mad(t, rd, ro)) * 0.5;
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
					const float cloudAltitude = _Radius - 0.015;
					const float oceanDist = sphereIntersect(ro, rd, _Radius + _SeaLevel + WAVE_HEIGHT - 0.0004).y;
					if (oceanDist > 0) dist = min(dist, oceanDist);

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
					//const float gap = groundDist(p);
					half2 uv = getSphereUV(p);
					half grass = grassLength(p);
					half3 albedo = half3(0.001, grass * 0.04 + 0.01, 0.0001);
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
						/*float blurSize = 1;
						atten = 0;
						for (int i = -blurSize; i <= blurSize; i++) {
							for (int j = -blurSize; j <= blurSize; j++) {
								float2 uv = coord.xy + float2(i * _ShadowTex_TexelSize.x, j * _ShadowTex_TexelSize.y);
								atten += tex2D(_ShadowTex, uv).r <= coord.z;
							}
						}

						atten /= (blurSize * 2 + 1) * (blurSize * 2 + 1);*/
					}

					//compare sphere normal to terrain normal to determine slope
					const float3 flatNor = normalize(p);
					const float slope = dot(nor, flatNor);
					const half3 slopeCol = half3(0.015, 0.0015, 0.001);
					albedo = lerp(albedo, slopeCol, saturate(mad(-2.5, slope, 2.5)));
					if (grass <= 0) albedo = slopeCol;

					const float beach = saturate((_Radius + BEACH - length(p) - (1 - slope) * 0.001) * 2000);
					float dots = tex2D(_GrassTex, uv * 1500);
					albedo = lerp(albedo, half3(0.07, 0.05, 0.04) - dots * 0.03, beach);

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

				half4 oceanColor(const float3 rd, const float3 lig, const float4 hit,
					const float4 oceanHit, const bool underwater, const float oceanDepth) {
					half4 color = 0;
					if (oceanDepth > 0) {
						float3 surfNor = normalize(oceanHit.xyz);
						//Water is more opaque the deeper it is, and darker on the night side of the planet
						const half3 deepWater = half3(0.0001, 0.001, 0.04);
						const half3 shallowWater = half3(0.0001, 0.03, 0.02);
						const half oceanEffect = 1 - exp(-oceanDepth * 300);
						const half3 waterCol = lerp(shallowWater, deepWater, oceanEffect);
						//const half nightSide = smoothstep(-0.1, 0, dot(lig, surfNor));
						color = half4(waterCol, oceanEffect);

						//can see ocean surface
						if (hit.w > oceanDepth) {
							const float3 waveNor = waveNormal(oceanHit.xyz);
							const half shadow = calcSoftshadow(oceanHit.xyz, lig) * saturate(dot(surfNor, lig));
							//ambient reflected skycolor
							const half fre = pow(saturate(1 - dot(waveNor, -rd)), 2);
							const half ref = reflect(rd, waveNor);
							color.rgb += half3(0.0025, 0.025, 0.2) * fre * shadow;
							color += smoothstep(0, 0.0001, max(dot(surfNor, waveNor) - oceanHit.w * 0.00003 - 0.99999, -groundDist(oceanHit.xyz) + 0.00005));
							//specular
							if (shadow > 0.01) {
								const float3 hal = normalize(lig - rd);
								//color += smoothstep(0.985, 1, saturate(dot(hal, waveNor)));
								color += pow(saturate(dot(hal, waveNor)), 128);
							}
							color.rgb *= shadow + 0.1;
							if (underwater) {
								color.rgb = lerp(color.rgb, waterCol, oceanEffect);
							}
						}
					}
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
						if (abs(dS) < EPSILON || dO > MAX_DIST) break;
						side = dS > 0;
						if (side != oldSide) mult *= 0.5;
						//dO += dS * mult;
						dO = mad(mult, dS, dO);
						oldSide = side;
					}
					return float4(p, dO);
				}

				half4 addOceanAtmo(float3 ro, float3 rd, float3 p, float dist, float3 lig, float2 air) {
					float oceanDepth = -1;
					if (sphereHit(ro, rd, _Radius + _SeaLevel + WAVE_HEIGHT + 0.0001)) {
						const float4 oceanHit = rmWater(ro, rd);
						const bool underwater = waterDist(ro) < 0;
						oceanDepth = dist - oceanHit.w;
						if (underwater) {
							oceanDepth = min(dist, oceanHit.w);
						}

						if (oceanDepth > 0) {
							half4 atmo = 0;
							if (!underwater) atmo = collectColor(ro, rd, lig, oceanHit.w, dot(rd, lig), air);
							half4 ocean = oceanColor(rd, lig, float4(p, dist), oceanHit, underwater, oceanDepth);
							return ocean;
						}
					}

					if (oceanDepth <= 0) {
						//hit only atmosphere
						return collectColor(ro, rd, lig, dist, dot(rd, lig), air);
					}
					return 0;
				}
			ENDCG

			Pass
			{
				Tags {"Queue" = "Transparent" "LightMode" = "ForwardBase"}
				ZTest Off
				Cull Off
				Blend SrcAlpha OneMinusSrcAlpha
				CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag

				fixed4 frag(v2f i, out float outDepth : SV_Depth) : SV_Target
				{
					const float3 ro = i.ro;
					const float3 rd = normalize(i.hitPos - ro);

					//calculate where the ray enters and exits the atmosphere
					const float2 air = sphereIntersect(ro, rd, 0.5);
					//if it missed the atmosphere it also missed the planet and can be ignored
					clip(air.y);

					const float2 screenUV = float2(i.pos.x / _ScreenParams.x, i.pos.y / _ScreenParams.y);
					const float depth = tex2D(_CameraDepthTexture, screenUV).r;

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
						//color.a = max(0.8 * (abs(hit.w) > air.y), color.a);
					}

					half4 clouds = addClouds(ro, rd, abs(hit.w), air);
					color.rgb = pow(color.rgb, 0.4545);
					color.rgb = lerp(color.rgb, clouds.rgb, clouds.a);
					color.a = saturate(clouds.a + color.a);
					return color;
				}
				ENDCG
			}

			/*Pass
			{
				Name "SHADOWCASTER"
				Tags { "LightMode" = "ShadowCaster" }

				ZWrite On ZTest LEqual

				CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag_shadow

				#pragma multi_compile_shadowcaster

				fixed4 frag_shadow(v2f i, out float outDepth : SV_Depth) : SV_Target
				{
					const float3 ro = i.ro;
					const float3 rd = normalize(i.hitPos - ro);

					const float2 air = sphereIntersect(ro, rd, 0.5);
					clip(air.y);

					const float4 hit = raymarch(ro, rd);
					if (hit.w >= MAX_DIST) clip(0);
					// calculate object space position from ray, front hit ray length, and ray origin
					float3 surfacePos = hit.xyz;

					// output modified depth
					float4 clipPos = UnityObjectToClipPos(hit.xyz);
					clipPos = UnityApplyLinearShadowBias(clipPos);
					outDepth = clipPos.z / clipPos.w;
					return 0;
				}
				ENDCG
			}*/
		}
}
