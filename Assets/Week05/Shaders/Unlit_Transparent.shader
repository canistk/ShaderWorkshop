Shader "Custom RP/Unlit Transparent" {
	
	Properties
	{
		_BaseMap("Texture", 2D) = "white" {}
		_BaseColor("Color", Color) = (1.0, 1.0, 1.0, 1.0)
		_Cutoff ("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
		[Toggle(_CLIPPING)] _Clipping ("Alpha Clipping", Float) = 0
		[Enum(UnityEngine.Rendering.BlendMode)]_SrcBlend ("Src Blend", Float) = 1
		[Enum(UnityEngine.Rendering.BlendMode)]_DstBlend ("Dst Blend", Float) = 0
		[Enum(Off, 0, On, 1)] _ZWrite ("Z Write", Float) = 1
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
			Blend [_SrcBlend] [_DstBlend]
			ZWrite [_ZWrite]
			Tags {
				"LightMode" = "CustomUnlit"
			}
			HLSLPROGRAM
			#pragma shader_feature _CLIPPING
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
				UNITY_DEFINE_INSTANCED_PROP(float4, _BaseMap_ST)
				UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
				UNITY_DEFINE_INSTANCED_PROP(float, _Cutoff)
			UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

			struct Attributes {
				float3 positionOS : POSITION;
				float2 baseUV : TEXCOORD0;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};
			struct Varyings {
				float4 positionCS : SV_POSITION;
				float2 baseUV : VAR_BASE_UV;
				UNITY_VERTEX_INPUT_INSTANCE_ID
			};

			Varyings UnlitPassVertex (Attributes input)
			{
				Varyings output;
				UNITY_SETUP_INSTANCE_ID(input);
				UNITY_TRANSFER_INSTANCE_ID(input, output);

				float3 positionWS = TransformObjectToWorld(input.positionOS);
				output.positionCS = TransformWorldToHClip(positionWS);

				float4 baseST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseMap_ST);
				output.baseUV = input.baseUV * baseST.xy + baseST.zw;
				return output;
			}

			float4 UnlitPassFragment (Varyings input) : SV_TARGET
			{
				UNITY_SETUP_INSTANCE_ID(input);
				float4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.baseUV);
				float4 baseColor = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseColor);
				float4 base = baseMap * baseColor;
				#if defined(_CLIPPING)
					clip(base.a - UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _Cutoff));
				#endif
				return base;

			}

			ENDHLSL
		}
	}
}