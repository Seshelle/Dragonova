Shader "Unlit/Starfield_Shader"
{
	Properties{
		//_Cube("Environment Map", Cube) = "white" {}
		_AtmoRad("Atmosphere Radius", float) = 10000
		_SunColor("Sun Color", Color) = (1, 1, 1, 1)
	}

	SubShader{

		Pass {
			Tags { "Queue" = "Background" }
			ZWrite Off
			Blend SrcAlpha OneMinusSrcAlpha

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#define PI 3.1415926535
			#define BANDS 500
			#define STAR_NUM 5
			#define STAR_MAX_SIZE 0.000002

			//samplerCUBE _Cube;
			float _AtmoRad;
			half4 _SunColor;

			struct vertexInput {
				float4 vertex : POSITION;
			};

			struct vertexOutput {
				float4 pos : SV_POSITION;
				float3 viewDir : TEXCOORD0;
			};

			vertexOutput vert(vertexInput input)
			{
				vertexOutput output;
				output.viewDir = mul(unity_ObjectToWorld, input.vertex).xyz - _WorldSpaceCameraPos;
				output.pos = UnityObjectToClipPos(input.vertex);
				return output;
			}

			float smoothstep(float edge0, float edge1, float x) {
				x = saturate((x - edge0) / (edge1 - edge0));
				return x * x * x * (x * (x * 6 - 15) + 10);
			}

			float3 randomf3(float seed)
			{
				float3 rand = frac(seed * float3(0.1113, 0.1131, 0.1311));
				rand += dot(rand, rand.zxy + 33.123);
				return frac(rand);
			}

			float brightness(float3 rd, float3 ld, float intensity) {
				return saturate(intensity / (1 - dot(rd, normalize(ld))));
			}

			bool sphereHit(float3 ro, float3 rd, float r) {
				float b = dot(ro, rd);
				float c = dot(ro, ro) - r * r;
				float h = b * b - c;
				return h >= 0 && dot(rd, -normalize(ro)) > 0;
			}

			// Absolute error <= 6.7e-5
			float facos(float x) {
				float negate = float(x < 0);
				x = abs(x);
				float ret = -0.0187293;
				ret = mad(x, ret, 0.0742610);
				ret = mad(x, ret, -0.2121144);
				ret = mad(x, ret, 1.5707288);
				ret = ret * sqrt(1.0 - x);
				ret = ret - 2 * negate * ret;
				return negate * 3.14159265358979 + ret;
			}

			fixed4 getStars(float3 rd) {
				float rayTheta = facos(rd.z);

				float width = PI / BANDS;

				float rayLevel = floor((rayTheta / PI) * BANDS);

				float theta;
				float phi;
				fixed4 color = 0;
				float dist;
				float level;
				float3 rand;

				for (float i = -3; i <= 3; i++) {

					level = min(BANDS, max(0, rayLevel + i));
					theta = (level + 0.5) * width;

					//remove stars at random near the poles to prevent bunching
					float st = sin(theta) - 0.3;
					if (st % 0.001 < -0.0002) {
						continue;
					}

					for (float j = 0; j < STAR_NUM; j++) {
						rand = randomf3(level + theta + j * 1000);
						phi = 2 * PI * rand.x;
						const float3 starPos = normalize(float3(sin(theta)*cos(phi),
							sin(theta)*sin(phi),
							cos(theta)));

						const float starDist = 1 - (0.5 + 0.5 * dot(starPos, rd));
						const float intensity = STAR_MAX_SIZE * pow(min((rand.z + 1) * 0.5, 1), 8);
						const float falloff = 1.5;

						//randomly pick a star color from within a color palette
						const float starx = abs(starPos.x % 0.001) * 1000;
						const float stary = abs(starPos.y % 0.001) * 1000;
						const fixed4 starColor = fixed4(
							1 - stary * (starx < 0.33),
							1 - stary * (starx < 0.66),
							1 - stary * (starx >= 0.33),
							1);

						color += starColor * pow(intensity / starDist, falloff);
					}
				}

				return color;
			}

			fixed4 frag(vertexOutput input) : COLOR {
				const float3 ro = _WorldSpaceCameraPos;

				//altitude is negative in atmosphere
				const float altitude = length(ro) / (_AtmoRad * 2) - 0.5;
				const float3 rd = normalize(input.viewDir);
				const float3 sunDir = float3(-1, 0, 0);

				//smoothly reduce star visibility when entering the atmosphere
				float maxAlpha = 100;
				const float atmoMult = smoothstep(-0.005, 0.1, altitude);

				//clamp maxAlpha to higher value when on nightside of planet
				const float sunDot = dot(normalize(ro), sunDir);
				const float night = smoothstep(0.15, 3, -sunDot);
				maxAlpha *= clamp(atmoMult, night, 1);

				if (altitude > 0 && sphereHit(ro, rd, _AtmoRad)) {
					maxAlpha *= saturate(night * 200);
				}

				fixed4 color = 0;
				//don't calculate non-sun stars when their final alpha will be zero
				if (maxAlpha > 0) {
					color = getStars(rd);
					color.a = min(maxAlpha, color.a);
				}

				//add sun regardless of atmosphere
				float sunIntensity = brightness(rd, sunDir, .0002);
				float3 sunDif = rd - sunDir;
				if (sunIntensity > 0.01 && sunIntensity < 1) {
					sunIntensity *= 0.9 + abs(sin(atan(sunDif.y / sunDif.z) * 10)) * 0.1;
				}
				color += sunIntensity * _SunColor * 3;

				color.rgb = pow(color.rgb, 0.4545);

				return color;
				//return texCUBE(_Cube, input.texcoord);
			}
			ENDCG
		}
	}
}