Shader "Custom/Erase Z-Buffer"
{
	SubShader
	{

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			struct v2f
			{
				float4 position : POSITION;
			};

			v2f vert(appdata_base v)
			{
				v2f o;
				o.position = UnityObjectToClipPos(v.vertex);
				return o;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				return 0;
			}
			ENDCG
		}

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"

			struct v2f
			{
				float4 position : POSITION;
			};

			struct fragOut
			{
				float depth : DEPTH;
			};

			v2f vert(appdata_base v)
			{
				v2f o;
				o.position = UnityObjectToClipPos(v.vertex);
				return o;
			}

			fragOut frag(in v2f i)
			{
				fragOut o;
				o.depth = 0;
				return o;
			}
			ENDCG
		}
	}
}