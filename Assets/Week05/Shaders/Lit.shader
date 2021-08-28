Shader "Custom RP/lit"
{
	Properties {
		_BaseMap("Texture", 2D) = "white" {}
		_BaseColor("Color", Color) = (0.5, 0.5, 0.5, 1.0)
	}

	SubShader
	{
		Pass {
			//Tags {
			//	"LightMode" = "CustomLit"
			//}
			HLSLPROGRAM
			#pragma multi_compile_instancing
			#pragma vertex LitPassVertex
			#pragma fragment LitPassFragment
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/UnityInstancing.hlsl"

			TEXTURE2D(_BaseMap);
			SAMPLER(sampler_BaseMap);

			UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
				UNITY_DEFINE_INSTANCED_PROP(float4, _BaseMap_ST)
				UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
			UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

			struct Attributes {
				float3 positionOS : POSITION;
				float3 normalOS : NORMAL;
				float2 baseUV : TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			struct Varyings {
				float4 positionCS : SV_POSITION;
				float3 normalWS : VAR_NORMAL;
				float2 baseUV : VAR_BASE_UV;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			Varyings LitPassVertex (Attributes input)
			{
				Varyings output;
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);

				float3 positionWS = TransformObjectToWorld(input.positionOS);
				output.positionCS = TransformWorldToHClip(positionWS);

				float4 baseST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseMap_ST);
				output.baseUV = input.baseUV * baseST.xy + baseST.zw;

				output.normalWS = TransformObjectToWorldNormal(input.normalOS);
				return output;
			}

			float4 LitPassFragment (Varyings input) : SV_TARGET
			{
				UNITY_SETUP_INSTANCE_ID(input);
				float4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.baseUV);
				float4 baseColor = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseColor);
				float4 base = baseMap * baseColor;
				base.rgb = input.normalWS;
				return base;
			}
			ENDHLSL
		}
	}
}