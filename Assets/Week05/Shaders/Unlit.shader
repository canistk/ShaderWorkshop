Shader "Custom RP/Unlit" {
	
	Properties
	{
		_BaseColor("Color", Color) = (1.0, 1.0, 1.0, 1.0)
	}
	
	SubShader
	{	
		Pass
		{
			HLSLPROGRAM
			#pragma multi_compile_instancing
			#pragma vertex UnlitPassVertex
			#pragma fragment UnlitPassFragment
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
			//CBUFFER_START(UnityPerMaterial)
			//	float4 _BaseColor;
			//CBUFFER_END

			UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
				UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
			UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

			struct Attributes {
				float3 positionOS : POSITION;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			struct Varyings {
				float4 positionCS : SV_POSITION;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			Varyings UnlitPassVertex (Attributes input)
			{
				Varyings output;
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);

				float3 positionWS = TransformObjectToWorld(input.positionOS);
				output.positionCS = TransformWorldToHClip(positionWS);

				return output;
			}

			float4 UnlitPassFragment (Varyings input) : SV_TARGET
			{
				UNITY_SETUP_INSTANCE_ID(input);
				//return _BaseColor;
				return UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseColor);
			}

			ENDHLSL
		}
	}
}