Shader "Custom RP/Unlit" {
	
	Properties
	{
		_BaseColor("Color", Color) = (1.0, 1.0, 1.0, 1.0)
	}
	
	SubShader
	{
		Pass {
			Name "GBuffer"
            Tags {
                "LightMode" = "GBuffer"
            }
			HLSLPROGRAM
			#pragma vertex GBufferPassVertex
			#pragma fragment GBufferPassFragment
			#include "GBufferPass.hlsl"
			ENDHLSL
		}
		Pass
		{
			Tags {
				"LightMode" = "CustomUnlit"
			}
			HLSLPROGRAM
			#pragma multi_compile_instancing
			#pragma vertex UnlitPassVertex
			#pragma fragment UnlitPassFragment
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"
			TEXTURE2D(_BaseMap);
			SAMPLER(sampler_BaseMap);
			TEXTURE2D(Rt_PositionWS);
			SAMPLER(sampler_Rt_PositionWS);
			TEXTURE2D(Rt_NormalWS);
			SAMPLER(sampler_Rt_NormalWS);
			TEXTURE2D(Rt_Albedo);
			SAMPLER(sampler_Rt_Albedo);
			TEXTURE2D(Rt_Depth);
			SAMPLER(sampler_Rt_Depth);

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
				// float4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.baseUV);
				float4 baseColor = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseColor);
				float4 base = baseColor;
				return base;
			}

			ENDHLSL
		}
	}
}