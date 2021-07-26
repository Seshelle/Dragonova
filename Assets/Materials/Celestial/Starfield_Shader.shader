Shader "Unlit/Starfield_Shader"
{
	Properties{
		//_Cube("Environment Map", Cube) = "white" {}
		_AtmoRad("Atmosphere Radius", float) = 10000
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
			#define STAR_DENSITY 1000

			//samplerCUBE _Cube;
			float _AtmoRad;

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
				return intensity / (1 - dot(rd, normalize(ld)));
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
				//ret = ret * x;
				//ret = ret + 0.0742610;
				ret = mad(x, ret, 0.0742610);
				//ret = ret * x;
				//ret = ret - 0.2121144;
				ret = mad(x, ret, -0.2121144);
				//ret = ret * x;
				//ret = ret + 1.5707288;
				ret = mad(x, ret, 1.5707288);
				ret = ret * sqrt(1.0 - x);
				ret = ret - 2 * negate * ret;
				return negate * 3.14159265358979 + ret;
			}

			fixed4 getStars(float3 rd) {
				float rayTheta = facos(rd.z);

				float width = PI / STAR_DENSITY;

				float rayLevel = floor((rayTheta / PI) * STAR_DENSITY);

				float theta;
				float phi;
				fixed4 color = 0;
				float dist;
				float level;
				float3 rand;

				for (float i = -5; i <= 5; i++) {

					level = min(STAR_DENSITY - 1, max(0, rayLevel + i));
					theta = (level + 0.5) * width;

					//remove stars at random near the poles to prevent bunching
					float st = sin(theta) - 0.3;
					if (st % 0.001 < -0.0002) {
						continue;
					}

					rand = randomf3(level + theta);
					phi = 2 * PI * rand.x;
					float3 starPos = normalize(float3(sin(theta)*cos(phi),
						sin(theta)*sin(phi),
						cos(theta)));

					const float starDist = 1 - (0.5 + 0.5 * dot(starPos, rd));
					const float intensity = 0.000001 * (0.1 + sin(rand.z));
					const float falloff = 1.5;
					color += pow(intensity / starDist, falloff);
				}

				return color;
			}

			fixed4 frag(vertexOutput input) : COLOR {
				const float3 ro = _WorldSpaceCameraPos;

				//altitude is negative in atmosphere
				const float altitude = length(ro) / 20000 - 0.5;
				const float3 rd = normalize(input.viewDir);
				const float3 sunDir = float3(-1, 0, 0);

				//smoothly reduce star visibility when entering the atmosphere
				float maxAlpha = 100;
				const float atmoMult = smoothstep(-0.005, 0.1, altitude);

				//clamp atmoMult to higher value when on nightside of planet
				const float sunDot = dot(normalize(ro), sunDir);
				const float night = smoothstep(0.15, 3, -sunDot);
				maxAlpha *= clamp(atmoMult, night, 1);

				if (altitude > 0 && sphereHit(ro, rd, _AtmoRad)) {
					maxAlpha *= saturate(night * 200);
				}

				fixed4 color = 0;
				//maxAlpha = 1000;
				//don't calculate non-sun stars when their final alpha will be zero
				[branch]if (maxAlpha > 0) {
					color = getStars(rd);
					color.a = min(maxAlpha, color.a);
				}

				//add sun regardless of atmosphere
				float sun = brightness(rd, sunDir, .0002);
				color += sun;
				color.a = saturate(color.a);
				color.rg += sun;

				color.rgb = pow(color.rgb, 0.4545);

				return color;
				//return texCUBE(_Cube, input.texcoord);
			}
			ENDCG
		}
	}
}