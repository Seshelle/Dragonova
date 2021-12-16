Shader "Unlit/Cutout_Shadow"
{
	Properties{
		_RotationSpeed("Planet Rotation Speed", float) = 0.1
		_MainTex("Planet Cube", CUBE) = "white" {}
		_ShadowTex("Shadow", 2D) = "Black" {}
		_Cutoff("half", float) = 0.5
	}
	SubShader{
		Tags { "Queue" = "AlphaTest" "RenderType" = "TransparentCutout" }
		LOD 200

		CGPROGRAM
		#pragma surface surf Standard fullforwardshadows addshadow vertex:vert alphatest:_Cutoff

		#pragma target 3.0

		samplerCUBE _MainTex;
		sampler2D _ShadowTex;
		float4 _ShadowTex_TexelSize;
		float _RotationSpeed;

		struct Input {
			float2 uv_MainTex;
			float3 worldPos;
		};

		float3 rotateZ(float3 p) {
			//convert planet rotation to radians
			float theta = -_Time.y * _RotationSpeed * 0.01745;
			float c = cos(theta);
			float s = sin(theta);

			float4x4 rot = float4x4(
				float4(c, 0, s, 0),
				float4(0, 1, 0, 0),
				float4(-s, 0, c, 0),
				float4(0, 0, 0, 1)
				);

			//rotate the point to match the rotated planet
			return mul(rot, p);
		}

		float planetDist(float3 p) {
			half3 color = texCUBElod(_MainTex, float4(rotateZ(p), 0));
			return length(p) - 5000 + (color.r + color.g) * 1000;
		}

		void vert(inout appdata_full v) {
			float3 shadowCoord0 = mul(unity_WorldToShadow[0], mul(unity_ObjectToWorld, v.vertex)).xyz;
			float4 coord = float4(shadowCoord0.xy, 0, 0);
			float shadow = tex2Dlod(_ShadowTex, coord).r;
			float3 ro = mul(unity_ObjectToWorld, v.vertex).xyz;
			float3 rd = float3(1, 0, 0);
			half dO = 0;
			half dS;
			half3 p = 0;
			half3 color = 0;
			[loop]for (half i = 0; i < 50; i++) {
				p = mad(dO, rd, ro);
				dS = planetDist(p);
				if (dS < 0.01) {
					p += rd;
					break;
				}
				dO += dS;
				if (dO > 20000) {
					break;
				}
			}

			v.vertex = mul(unity_WorldToObject, float4(p, 1));
		}

		void surf(Input IN, inout SurfaceOutputStandard o) {
			//float3 coord = mul(unity_WorldToShadow[0], float4(IN.worldPos, 1)).xyz;
			//float shadow = tex2D(_ShadowTex, coord.xy).r;
			//o.Alpha = planetDist(IN.worldPos) < 0.1;
			o.Alpha = 1;
		}
		ENDCG
	}
	FallBack "Transparent/Cutout/Diffuse"
}
