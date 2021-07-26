Shader "Unlit/Planet_Shader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_Radius ("Radius", float) = 0.4
		_Scale ("Scale", float) = 2
		_DetailScale ("Detail Scale", float) = 1
		_SeaLevel ("Sea Level", float) = 0.45
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
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
                UNITY_FOG_COORDS(1)
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

            v2f vert (appdata v)
            {
                v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.ro = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1));
				o.hitPos = v.vertex;
				o.time = _Time;
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
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

			float getHeight(float3 p) {
				
				p = normalize(p);
				float colXZ = 0;
				float colYZ = 0;
				float colXY = 0;

				float3 DXZ = tex2Dlod(_MainTex, float4(p.xz*.5 + .5, 0, 0));
				float3 DYZ = tex2Dlod(_MainTex, float4(p.yz*.5 + .5, 0, 0));
				float3 DXY = tex2Dlod(_MainTex, float4(p.xy*.5 + .5, 0, 0));

				colXZ += DXZ.r * _Scale + DXZ.g * _DetailScale;
				colYZ += DYZ.r * _Scale + DYZ.g * _DetailScale;
				colXY += DXY.r * _Scale + DXY.g * _DetailScale;

				//colXZ += tex2D(_MainTex, p.xz * 100).r / 5000;
				//colYZ += tex2D(_MainTex, p.yz * 100).r / 5000;
				//colXY += tex2D(_MainTex, p.xy * 100).r / 5000;

				p = abs(p);
				p *= p;
				p /= p.x + p.y + p.z;

				return colYZ * p.x + colXZ * p.y + colXY * p.z;
			}

			float3 testColor(float3 p) {
				p = normalize(p);
				float colXZ = 0;
				float colYZ = 0;
				float colXY = 0;

				float3 DXZ = tex2D(_MainTex, p.xz*.5 + .5);
				float3 DYZ = tex2D(_MainTex, p.yz*.5 + .5);
				float3 DXY = tex2D(_MainTex, p.xy*.5 + .5);

				colXZ += DXZ.r * _Scale + DXZ.g * _DetailScale;
				colYZ += DYZ.r * _Scale + DYZ.g * _DetailScale;
				colXY += DXY.r * _Scale + DXY.g * _DetailScale;

				p = abs(p);
				p *= p;
				p /= p.x + p.y + p.z;

				float3 test = float3(p.x, DYZ.r, 0);
				if (DYZ.r >= 0.5) test.b = 1;
				return test;
			}

			float smin(float a, float b, float k)
			{
				float h = clamp(0.5 + 0.5*(b - a) / k, 0.0, 1.0);
				return lerp(b, a, h) - k * h*(1.0 - h);
			}

			float GetDist(float3 p) {
				float height = getHeight(p);
				float land = length(p) - _Radius - height;
				float ocean = length(p) - _SeaLevel - _Radius;
				return min(land, ocean);
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

			float calculateObstruction(float3 pos, float3 lpos)
			{
				float3 dir = normalize(lpos - pos);
				float rad = 0.1;
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

				float3 light1Pos = float3(-50.0, 35.0, 0.0);
				float3 light1Intensity = float3(0.4, 0.4, 0.4);

				float obs = calculateObstruction(p, light1Pos);
				if (obs > EPSILON) specular = float3(0, 0, 0);

				float3 cont = phongContribForLight(diffuse, specular, alpha, p, eye, light1Pos, light1Intensity);
				color += cont * (1. - obs);

				return color;
			}

            fixed4 frag (v2f i) : SV_Target
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

				float3 albedo = float3(0.005, 0.015, 0);
				float3 diffuse = float3(0.6, 1, 0);
				float3 specular = float3(0, 0, 0);
				float shininess = 300;

				float height = getHeight(p);
				float ocean = _SeaLevel - height;

				if (ocean >= 0) {
					albedo = float3(0, 0, 0.001);
					//albedo.y = lerp(0.001, 0, ocean * 300);
					diffuse = float3(0, 0, 0.5);
					diffuse.y = lerp(0.1, 0, ocean * 300);
					specular = float3(1, 1, 1);
				}

				color.rgb = phongIllumination(albedo, diffuse, specular, shininess, p, ro);
				color.rgb = pow(color, float3(1.0 / 2.2, 1.0 / 2.2, 1.0 / 2.2));

                UNITY_APPLY_FOG(i.fogCoord, col);
                return color;
            }
            ENDCG
        }
    }
}
