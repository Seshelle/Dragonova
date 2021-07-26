Shader "Unlit/Planet_Shader_Ver3"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
		_Radius("Radius", float) = 0.4
		_Scale("Scale", float) = 2
		_SeaLevel("Sea Level", float) = 0.45
		_AtmoRadius("Atmosphere Radius", float) = 0.1
	}
		SubShader
		{
			Tags { "RenderType" = "Opaque" }
			LOD 100
			Cull Front

			CGINCLUDE

			ENDCG

			Pass
			{
				CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag

				#include "UnityCG.cginc"

				#define MAX_DIST 10
				#define MAX_STEPS 300
				#define WATER_STEPS 64
				#define SH_STEPS 64
				#define STMAX 3
				#define EPSILON 0.00001

				sampler2D _MainTex;
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
					float4 vertex : SV_POSITION;
					float3 ro : TEXCOORD0;
					float3 hitPos : TEXCOORD2;
				};

				v2f vert(appdata v)
				{
					v2f o;
					o.vertex = UnityObjectToClipPos(v.vertex);
					o.ro = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1));
					o.hitPos = v.vertex;
					return o;
				}

				float smoothstep(float edge0, float edge1, float x) {
					x = clamp((x - edge0) / (edge1 - edge0), 0, 1);
					return x * x * x * (x * (x * 6 - 15) + 10);
				}

				half2 getSphereUV(const float3 p) {
					half3 octant = sign(p);

					// Scale the vector so |x| + |y| + |z| = 1 (surface of octahedron).
					half sum = dot(p, octant);
					half3 octahedron = p / sum;

					// "Untuck" the corners using the same reflection across the diagonal as before.
					// (A reflection is its own inverse transformation).
					if (octahedron.z < 0) {
						half3 absolute = abs(octahedron);
						octahedron.xy = octant.xy * float2(1 - absolute.y, 1 - absolute.x);
					}

					half2 uv = octahedron.xy * 0.5 + 0.5;

					return uv;
				}

				half2 difSphereUV(const float3 p) {
					half3 octant = sign(p);

					// Scale the vector so |x| + |y| + |z| = 1 (surface of octahedron).
					half sum = dot(p, octant);
					half3 octahedron = p / sum;

					half2 uv = octahedron.xy * 0.5 + 0.5;

					return uv;
				}

				half3 getColor(float3 p) {
					return tex2Dlod(_MainTex, float4(getSphereUV(p), 0, 0));
				}

				float hash1(float2 p)
				{
					p = 50.0*frac(p*0.3183099);
					return frac(p.x*p.y*(p.x + p.y));
				}

				float noise(float2 x)
				{
					float2 p = floor(x);
					float2 w = frac(x);
					float2 u = w * w*w*(w*(w*6.0 - 15.0) + 10.0);

					float a = hash1(p + float2(0, 0));
					float b = hash1(p + float2(1, 0));
					float c = hash1(p + float2(0, 1));
					float d = hash1(p + float2(1, 1));

					return -1.0 + 2.0*(a + (b - a)*u.x + (c - a)*u.y + (a - b - c + d)*u.x*u.y);
				}

				half getHeight(const float3 p) {
					half2 uv = getSphereUV(p);
					half2 map = tex2Dlod(_MainTex, half4(uv, 0, 0)).rg;

					//blend the seams with terrain from another area
					const half blend = max(abs(uv.x - 0.5), abs(uv.y - 0.5));
					if (blend > 0) {
						half2 adj = tex2Dlod(_MainTex, half4(difSphereUV(p), 0, 0)).rg;
						map = lerp(map, adj, clamp(pow(blend * 2, 8), 0, 1));
					}

					//return noise(uv * 20) * _Scale;
					return -(map.r + map.g / 500) * _Scale;
				}

				half waveHeight(const float3 p) {
					const half depth = (_Radius + _SeaLevel) - getHeight(p);
					//half randWave = tex2Dlod(_MainTex, float4(getSphereUV(p), 0, 0)).g;
					const half wHeight = 0.0001;
					const half inWave = cos(depth * 2000 + _Time.z / 2) * wHeight;
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
						p = ro + dO * rd;
						dS = waterDist(p);
						dO += dS * under;
						if (abs(dS) < EPSILON || dO > MAX_DIST + 10) break;
					}
					return float4(p, dO);
				}

				float4 raymarch(const float3 ro, const float3 rd) {
					float dO = EPSILON * 3;
					float dS;
					float3 p = 0;
					//float distMult = 0.1;
					/*[loop]for (half i = 0; i < MAX_STEPS; i++) {
						p = ro + dO * rd;
						dS = getDist(p);
						dO += dS * distMult;
						distMult = atan(dO + 1) * 2 / 3.14159;
						if (abs(dS) < EPSILON || dO > MAX_DIST) break;
					}*/
					float side = sign(getDist(p));
					float oldSide = side;
					float mult = 1;
					[loop]for (half i = 0; i < MAX_STEPS; i++) {
						p = ro + dO * rd;
						dS = getDist(p);
						side = sign(dS);
						if (side != oldSide) mult *= 0.5;
						dO += dS * mult;
						if (abs(dS) < EPSILON || dO > MAX_DIST) break;
						oldSide = side;
					}
					return float4(p, dO);
				}

				float3 waveNormal(const float3 pos) {
					const float2 e = float2(1.0, -1.0)*0.5773*0.0005;
					return normalize(e.xyy*waterDist(pos + e.xyy) +
						e.yyx*waterDist(pos + e.yyx) +
						e.yxy*waterDist(pos + e.yxy) +
						e.xxx*waterDist(pos + e.xxx));
				}

				float3 getNormal(const float3 pos)
				{
					//const float2 e = float2(1.0, -1.0)*0.5773*0.0005;
					const float2 e = float2(1.0, -1.0)*0.5773*0.0008;
					return normalize(e.xyy*getDist(pos + e.xyy) +
						e.yyx*getDist(pos + e.yyx) +
						e.yxy*getDist(pos + e.yxy) +
						e.xxx*getDist(pos + e.xxx));
				}

				float2 sphereIntersect(float3 ro, float3 rd, float r) {
					float b = dot(ro, rd);
					float c = dot(ro, ro) - r*r;
					float h = b * b - c;
					if (h < 0) return -1; // no intersection
					h = sqrt(h);
					return float2(-b - h, -b + h);
				}

				half calcSoftshadow(const float3 ro, const float3 rd)
				{
					half res = 1.0;
					half t = 0.001;
					half ph = 1e10; // big, such that y = 0 on the first iteration

					[loop]for (half i = 0; i < SH_STEPS; i++)
					{
						half h = getDist(ro + rd * t);
						half y = h * h / (2.0*ph);
						//float d = sqrt(h*h - y * y);
						half d = max(h, y) + min(h, y) / 2;
						//float d = length(float2(h, y));
						res = min(res, 10.0*d / max(0.0, t - y));
						ph = h;

						t += h;

						if (res < EPSILON || t>STMAX) break;

					}
					res = clamp(res, 0.0, 1.0);
					return res * res*(3.0 - 2.0*res);
				}

				float calcAO(float3 pos, float3 nor)
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
					return clamp(1.0 - 1.5*occ, 0.0, 1.0);
				}

				half3 atmoColor(float horizon, float sunDot) {
					const half3 skyColor = half3(0.001, 0.01, 1);
					half3 sunsetColor = half3(0.1, 0.002, 0);
					fixed3 finalColor = lerp(skyColor, sunsetColor, smoothstep(0.1, 0.2, horizon));
					finalColor = lerp(finalColor, 0, smoothstep(0, 0.3, horizon));

					return finalColor;
				}

				half3 collectColor(float3 ro, float3 rd, float3 ld, float dist, float sunDot, float2 ray_length) {			
					if (ray_length.x > ray_length.y) return 0;
					//set end point of ray to the planet if it hit the planet
					ray_length.y = min(ray_length.y, dist);
					//the start of ray is where it enters the atmosphere
					ray_length.x = max(ray_length.x, 0.0);

					float3 enter = ro + rd * ray_length.x;
					half horizon = sphereIntersect(ro, ld, _Radius - _Scale / 4).y;
					//density for how much atmosphere it passes through
					half div = 2 - sunDot;
					if (dist <= MAX_DIST) div = 3;
					half density = (ray_length.y - ray_length.x) * 15 / div;
					return atmoColor(horizon, sunDot) * pow(density, 4);
				}

				fixed4 frag(v2f i, out float outDepth : SV_Depth) : SV_Target
				{
					const float3 ro = i.ro;
					const float3 rd = normalize(i.hitPos - ro);

					//calculate where the ray enters and exits the atmosphere
					const float2 air = sphereIntersect(ro, rd, _Radius /*+ _AtmoRadius*/);
					//if it missed the atmosphere it also missed the planet and can be ignored
					if (air.y < 0) discard;

					const float4 hit = raymarch(ro, rd);

					const float t = hit.w;
					const float3 p = hit.xyz;
					half4 color = half4(0, 0, 0, 1);
					const float3 lig = normalize(mul(unity_WorldToObject, float3(-1.0, 0, 0)));
					const half sunDot = dot(rd, lig);

					if (t < MAX_DIST) {
						//half3 albedo = half3(0.0001, 0.05, 0);
						half3 albedo = half3(0.0001, 0.05, 0);
						//half3 specular = half3(1.00, 0.70, 0.5);
						const float3 nor = getNormal(p);

						//compare sphere normal to land normal to determine slope
						const float3 flatNor = normalize(p);
						const float slope = dot(nor, flatNor);
						const half3 slopeCol = half3(0.015, 0.0015, 0.001);
						albedo = lerp(albedo, slopeCol, clamp((1 - slope) * 2.5, 0, 1));

						float beach = _Radius + _SeaLevel + 0.002 - length(p);
						beach = clamp(beach * 1000, 0, 1);
						albedo = lerp(albedo, half3(0.07, 0.05, 0.04), beach);

						// key light
						half dif = clamp(dot(nor, lig), 0.0, 1.0) * calcSoftshadow(p, lig);
						color.rgb += albedo * 2.0 * dif;

						// ambient light
						//float occ = calcAO(p, nor);
						const half3 ambColor = lerp(atmoColor(dot(flatNor, lig) + 0.3, dot(nor, lig)), half3(0.015, 0.08, 0.1), 0.1);
						color.rgb += albedo * ambColor; //* occ;
					}
					else if (sunDot > 0.999) {
						color.rgb += 3;
					}

					const float4 oceanHit = rmWater(ro, rd);
					const float waterD = waterDist(ro);
					const bool underwater = waterD < 0;
					float oceanDepth = hit.w - oceanHit.w;
					if (underwater) {
						oceanDepth = min(hit.w, oceanHit.w);
					}
					//const float shoreDepth = length(oceanHit.xyz) - getHeight(oceanHit.xyz);
					if (oceanDepth > 0) {
						float3 surfNor = normalize(oceanHit.xyz);
						//Water is more opaque the deeper it is, and darker on the night side of the planet
						const half3 deepWater = half3(0.0001, 0.001, 0.04);
						const half3 shallowWater = half3(0.0001, 0.03, 0.02);
						const half oceanEffect = clamp(1 - exp(-oceanDepth * 300), 0.9, 0.999);
						const half3 waterCol = lerp(shallowWater, deepWater, oceanEffect);
						const half nightSide = smoothstep(-0.1, 0, dot(lig, surfNor));
						if (!underwater) {
							color.rgb = lerp(color.rgb, waterCol, oceanEffect);
							color.rgb *= (nightSide + 0.01);
						}

						//can see ocean surface
						if (hit.w > oceanDepth) {
							const float3 waveNor = waveNormal(oceanHit.xyz);
							//ambient skycolor
							const half fre = pow(clamp(1 + dot(rd, waveNor), 0, 1), 4);
							const half3 ref = reflect(surfNor, waveNor);
							color.rgb += nightSide * fre * smoothstep(0, 1, ref) * half3(0.015, 0.1, 1);
							//add basic specular
							if (!underwater) {
								const float3 hal = normalize(lig - rd);
								color.rgb += pow(max(0, dot(hal, waveNor)), 64) * nightSide * 3;
							}
						}
						if (underwater) {
							color.rgb = lerp(color.rgb, waterCol, oceanEffect);
						}
					}
					if (!underwater)color.rgb += collectColor(ro, rd, lig, min(t, oceanHit.w), sunDot, air);

					//gamma correction
					color.rgb = pow(color, 0.4545);

					// output modified depth
					if (hit.w < MAX_DIST) {
						const float4 clipPos = UnityWorldToClipPos(mul(unity_ObjectToWorld, hit.xyz));
						outDepth = clipPos.z / clipPos.w;
					}

					//return oceanHit.w;
					return color;
				}
				ENDCG
			}
		}
}
