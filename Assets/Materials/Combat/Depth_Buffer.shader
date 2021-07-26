Shader "Unlit/Depth_Buffer_Display"
{
	Properties
	{
		_StartTime("Start Time", float) = 0
	}


	SubShader
	{
		Tags {"Queue" = "Transparent" "RenderType" = "Opaque"}
		LOD 100
		ZWrite Off
		Blend SrcAlpha OneMinusSrcAlpha

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

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
				float3 ro : TEXCOORD0;
				float3 hitPos : TEXCOORD1;
				float4 time : TEXCOORD2;
			};

			sampler2D _CameraDepthTexture;

			v2f vert(appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.ro = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1));
				o.hitPos = v.vertex;
				o.time = _Time;
				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				float3 ro = i.ro;
				float3 rd = normalize(i.hitPos - ro);
				fixed4 color = 1;

				float2 screenUV = float2(i.vertex.x / _ScreenParams.x, i.vertex.y / _ScreenParams.y);

				//get distance from depth texture
				float depth = tex2D(_CameraDepthTexture, screenUV).r;
				depth = Linear01Depth(depth);
				//depth = depth * _ProjectionParams.z;
				color.rgb = depth;

				return color;
			}
			ENDCG
		}
	}
}
