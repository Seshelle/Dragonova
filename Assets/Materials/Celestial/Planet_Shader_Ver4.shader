Shader "Unlit/Planet_Shader_Ver4"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
		_Radius("Radius", float) = 0.4
		_Scale("Scale", float) = 2
		_DetailScale("Detail Scale", float) = 1
		_SeaLevel("Sea Level", float) = 0.45
	}
		SubShader
		{
			Tags { "RenderType" = "Opaque" }
			LOD 100
			Cull Off

			Pass
			{
				CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag
				// make fog work
				#pragma multi_compile_fog

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
				float4 _MainTex_ST;
				float _Radius;
				float _Scale;
				float _DetailScale;
				float _SeaLevel;

				v2f vert(appdata v)
				{
					v2f o;
					o.vertex = UnityObjectToClipPos(v.vertex);
					o.ro = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1));
					o.hitPos = v.vertex;
					o.time = _Time;
					return o;
				}

				float getHeight(float3 p) {

					p = normalize(p);
					float colXZ = 0;
					float colYZ = 0;
					float colXY = 0;

					//float3 DXZ = tex2Dlod(_MainTex, float4(p.xz*.5 + .5, 0, 0));
					//float3 DYZ = tex2Dlod(_MainTex, float4(p.yz*.5 + .5, 0, 0));
					//float3 DXY = tex2Dlod(_MainTex, float4(p.xy*.5 + .5, 0, 0));

					//colXZ += DXZ.r * _Scale + DXZ.g * _DetailScale;
					//colYZ += DYZ.r * _Scale + DYZ.g * _DetailScale;
					//colXY += DXY.r * _Scale + DXY.g * _DetailScale;

					//colXZ += tex2D(_MainTex, p.xz * 100).r / 5000;
					//colYZ += tex2D(_MainTex, p.yz * 100).r / 5000;
					//colXY += tex2D(_MainTex, p.xy * 100).r / 5000;

					p = abs(p);
					p *= p;
					p /= p.x + p.y + p.z;
					return 0;
					//return colYZ * p.x + colXZ * p.y + colXY * p.z;
				}

				float getDist(float3 p) {
					float height = getHeight(p);
					float land = length(p) - _Radius - height;
					float ocean = length(p) - _SeaLevel - _Radius;
					return min(land, ocean);
				}

				float4 raymarch(float3 ro, float3 rd) {
					float dO = 0;
					float dS;
					float3 p = 0;
					[loop]for (int i = 0; i < MAX_STEPS; i++) {
						p = ro + dO * rd;
						dS = getDist(p);
						dO += dS / 2;
						if (dS < EPSILON * dO * 100 || dO > MAX_DIST) break;
					}
					return float4(p, dO);
				}

				float3 getNormal(float3 pos)
				{
					float2 e = float2(1.0, -1.0)*0.5773*0.0005;
					return normalize(e.xyy*getDist(pos + e.xyy) +
						e.yyx*getDist(pos + e.yyx) +
						e.yxy*getDist(pos + e.yxy) +
						e.xxx*getDist(pos + e.xxx));
				}

				float2 sphereIntersect(float3 start, float3 dir, float r) {
					float a = dot(dir, dir);
					float b = 2.0 * dot(dir, start);
					float c = dot(start, start) - (r * r);
					float d = (b*b) - 4.0*a*c;
					if (d < 0.0) return float2(1e5, -1e5);
					return float2(
						(-b - sqrt(d)) / (2.0*a),
						(-b + sqrt(d)) / (2.0*a)
					);
				}

				float3 getColor(float3 p) {

					p = normalize(p);
					float3 colXZ = 0;
					float3 colYZ = 0;
					float3 colXY = 0;

					colXZ += tex2D(_MainTex, p.xz*.5 + .5);
					colYZ += tex2D(_MainTex, p.yz*.5 + .5);
					colXY += tex2D(_MainTex, p.xy*.5 + .5);

					p = abs(p);
					p *= pow(p, 1);
					p /= p.x + p.y + p.z;

					return colYZ * p.x + colXZ * p.y + colXY * p.z;
				}

				float calcSoftshadow(float3 ro, float3 rd, float tmax)
				{
					float res = 1.0;
					float t = 0.001;
					float ph = 1e10; // big, such that y = 0 on the first iteration

					[loop]for (int i = 0; i < 300; i++)
					{
						float h = getDist(ro + rd * t);
						float y = h * h / (2.0*ph);
						float d = sqrt(h*h - y * y);
						res = min(res, 10.0*d / max(0.0, t - y));
						ph = h;

						t += h;

						if (res<EPSILON || t>tmax) break;

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

				float3 atmoColor(float3 ro, float3 rd, float3 ld, float dist, float sunset) {
					//collect light as you go through the atmosphere
					const float steps = 16;
					const float3 skyColor = float3(0.2, 0.6, 3);
					const float3 sunsetColor = float3(1, 0.002, 0);

					// calculate the start and end position of the ray, as a distance along the ray
					// we do this with a ray sphere intersect
					float a = dot(rd, rd);
					float b = 2.0 * dot(rd, ro);
					float c = dot(ro, ro) - (0.45 * 0.45);
					float d = (b * b) - 4.0 * a * c;

					// stop early if there is no intersect
					if (d < 0.0) return 0;

					// calculate the ray length
					float2 ray_length = float2(
						max((-b - sqrt(d)) / (2.0 * a), 0.0),
						min((-b + sqrt(d)) / (2.0 * a), dist)
					);
					if (ray_length.x > ray_length.y) return 0;
					ray_length.y = min(ray_length.y, dist);
					ray_length.x = max(ray_length.x, 0.0);;

					float step_size = (ray_length.y - ray_length.x) / steps;
					float rayStart = ray_length.x + step_size * 0.5;
					float3 color = 0;

					for (int i = 0; i < steps; i++) {
						float3 p = ro + rd * (rayStart + step_size * i);

						float horizon = dot(normalize(p), ld);

						float3 finalColor = 0;
						if (horizon < 0) {
							//sun is more than halfway below horizon, start applying night effects
							finalColor = lerp(sunsetColor, 0, -horizon * 8);
						}
						else if (horizon < sunset && horizon > 0) {
							//sun is close to horizon, apply sunset effects
							finalColor = lerp(sunsetColor, skyColor, horizon * (1 / sunset));
						}
						else {
							finalColor = skyColor;
						}
						if (length(p) > 0.445) finalColor = finalColor / 5;
						color += finalColor / steps;
					}
					return color;
				}

				fixed4 frag(v2f i) : SV_Target
				{
					float3 ro = i.ro;
					float3 rd = normalize(i.hitPos - ro);

					//calculate where the ray enters and exits the atmosphere
					float2 air = sphereIntersect(ro, rd, _Radius + 0.05);
					//if it misses the atmosphere it also missed the planet and can be ignored
					if (air.x > MAX_DIST || air.y < 0) discard;

					float3 lig = normalize(float3(-50, 35, 0));

					float4 hit = raymarch(ro, rd);
					float t = hit.w;
					float4 color = float4(0, 0, 0, 1);
					bool hitPlanet = false;

					//if the ray hit the planet, add the planet's color
					if (t < MAX_DIST) {
						hitPlanet = true;
						float3 albedo = float3(0, 0.1, 0);
						float3 specular = float3(1.00, 0.70, 0.5);
						float3 p = hit.xyz;
						float3 nor = getNormal(p);

						float height = getHeight(p);
						float ocean = _SeaLevel - height;
						float speInt = 0;
						if (ocean >= 0) {
							albedo = float3(0, 0, 0.1);
							speInt = 12;
						}

						// key light
						float3 hal = normalize(lig - rd);
						float dif = clamp(dot(nor, lig), 0.0, 1.0) * calcSoftshadow(p, lig, 3.0);
						float spe = pow(clamp(dot(nor, hal), 0.0, 1.0), 16.0)* dif * (0.04 + 0.96*pow(clamp(1.0 + dot(hal, rd), 0.0, 1.0), 5.0));

						color.rgb = albedo * 2.0 * dif * specular;
						color.rgb += speInt * spe * specular;

						// ambient light
						float occ = calcAO(p, nor);
						float amb = clamp(0.5 + 0.5*nor.y, 0.0, 1.0);
						color.rgb += albedo * amb*occ*float3(0.0, 0.08, 0.1);
					}

					float sunDot = 0;
					if (!hitPlanet) {
						const float cut = 0.;
						sunDot = max(0, dot(rd, lig) - cut);
						if (sunDot + cut > 0.999) {
							color.rgb += 3;
						}
						sunDot *= sunDot * sunDot;
					}

					const float sunset = 0.1;
					if (length(ro) < 0.45) {
						//get the amount of atmosphere the ray passes through
						//use this to determine how much to mix the skycolor
						float density = min(t, air.y) - max(0, air.x);
						density = pow(density, 2);

						float horizon = dot(normalize(ro), lig);

						float3 skyColor = float3(0.1, 0.3, 1.5);
						float3 sunsetColor = float3(0.3, 0.001, 0);
						float hDot = dot(rd, normalize(ro));
						hDot *= hDot;
						sunsetColor *= max(sunDot, 0.05);
						float3 finalColor = skyColor;
						if (horizon < 0) {
							//sun is more than halfway below horizon, start applying night effects
							finalColor = lerp(sunsetColor, 0, -horizon * 5);
						}
						else if (horizon < sunset && horizon > 0) {
							//sun is close to horizon, apply sunset effects
							finalColor = lerp(sunsetColor, skyColor, horizon * (1 / sunset));
						}
						finalColor = finalColor * density * 10;
						color.rgb += lerp(finalColor, color.rgb, 0.5);
					}
					else {
						color.rgb = lerp(atmoColor(ro, rd, lig, t, sunset), color.rgb, 0.95);
					}

					//gamma correction
					//color.rgb = pow(color, 0.4545);

					return color;
				}
				ENDCG
			}
		}
}
