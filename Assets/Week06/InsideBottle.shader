// Study Ref : https://www.patreon.com/posts/shader-part-2-24996282
// Study Ref : https://developer.nvidia.com/gpugems/gpugems2/part-ii-shading-lighting-and-shadows/chapter-19-generic-refraction-simulation
Shader "Kit/Week06/Inside Bottle"
{
    Properties
    {
        _MainTex("Main Texture", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1,1)
		[Enum(UnityEngine.Rendering.BlendMode)]_SrcBlend ("Src Blend", Float) = 1
		[Enum(UnityEngine.Rendering.BlendMode)]_DstBlend ("Dst Blend", Float) = 10
		[Enum(Off, 0, On, 1)] _ZWrite ("Z Write", Float) = 1
        [IntRange]_Stencil("Stencil ID", Range(0,255)) = 2
    }

    SubShader
    {
        // https://docs.unity3d.com/Manual/SL-SubShaderTags.html
        Tags {
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalRenderPipeline"
            "Queue" = "Transparent+1"
        }
        LOD 100
        Pass
        {
            Name "ForwardLit"
			Tags {
				"LightMode" = "UniversalForward"
			}
            Stencil
			{
				Ref [_Stencil]
				Comp equal
                // WriteMask 2
                ReadMask 2
			}
            ZWrite [_ZWrite]
            ZTest GEqual
            Blend [_SrcBlend] [_DstBlend]
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            
            //#pragma multi_compile_fog
            #pragma target 3.0
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"



            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
                UNITY_DEFINE_INSTANCED_PROP(half4, _Color)
            UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)
            

            struct Attributes
            {
                half4   positionOS  : POSITION;
                half2   uv          : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                half4   positionCS  : SV_POSITION;
                half2   uv          : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_TRANSFER_INSTANCE_ID(IN, OUT);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);
                VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.positionOS.xyz);
                // VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);

                // OUT.positionCS = mul(UNITY_MATRIX_VP, half4(IN.positionOS, 1));
                OUT.positionCS = vertexInput.positionCS;
                OUT.uv = IN.uv;
                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                half4 MainTex = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);
                return MainTex * _Color;
            }
            ENDHLSL
        }
    }
}