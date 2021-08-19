Shader "Kit/Universal Render Pipeline/URPUnlitShaderTransparent"
{
    Properties
    {
        _Color("Debug Color", color) = (0.0,1.0,0.0,1.0)

        //====================================== below = usually can ignore in normal use case =====================================================================
        [Header(Stencil)]
        [IntRange]_Stencil("Stencil ID", Range(0,255)) = 0

        // https://docs.unity3d.com/ScriptReference/Rendering.CompareFunction.html
        // Disable = 0
        // Never = 1
        // Less = 2
        // Equal = 3
        // LessEqual = 4
        // Greater = 5
        // NotEqual = 6
        // GreaterEqual = 7
        // Always = 8 (default)
        [Enum(UnityEngine.Rendering.CompareFunction)]_StencilComp("Stencil Comparison", Float) = 3

        [IntRange]_StencilWriteMask ("Stencil Write Mask", Range(0,255)) = 255
        [IntRange]_StencilReadMask ("Stencil Read Mask", Range(0,255)) = 255
        [Enum(UnityEngine.Rendering.StencilOp)]_StencilPass ("Stencil Pass", Float) = 0
        [Enum(UnityEngine.Rendering.StencilOp)]_StencilFail ("Stencil Fail", Float) = 0
        [Enum(UnityEngine.Rendering.StencilOp)]_StencilZFail ("Stencil ZFail", Float) = 0
    }

    SubShader
    {
        // https://docs.unity3d.com/Manual/SL-SubShaderTags.html
        Tags {
            "RenderType" = "Transparent"
            "Queue" = "Overlay" // Queue : { Background, Geometry, AlphaTest, Transparent, Overlay }
            "RenderPipeline" = "UniversalPipeline"
            "DisableBatching" = "True"
        }
        LOD 100
        

        Pass
        {
            Name "ForwardLit"
			Tags {
				"LightMode" = "UniversalForward"
			}
			Cull Off
            ZTest LEqual
            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
            };   
            Varyings vert(float4 positionOS : POSITION)
            {
                Varyings OUT;
                VertexPositionInputs vertexPositionInput = GetVertexPositionInputs(positionOS.xyz);
                OUT.positionCS = vertexPositionInput.positionCS;
                return OUT;
            }
            float4 frag(Varyings IN) : SV_Target
            {
                return float4(0,0,0,0.5);
            }
            ENDHLSL
        }
        Pass
        {
            Name "DebugStencil"
			Tags {
				"LightMode" = "SRPDefaultUnlit"
			}
            Stencil
			{
				Ref [_Stencil] // 0 ~ 255
				Comp[_StencilComp] // default:always
                Pass [_StencilPass] // default:Keep

				ReadMask [_StencilReadMask]
                WriteMask [_StencilWriteMask]
                Fail [_StencilFail]
                ZFail [_StencilZFail]
			}
            Cull Off
            ZTest Always
            ZWrite Off

            // https://docs.unity3d.com/Manual/shader-shaderlab-commands.html
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // due to using ddx() & ddy()
            #pragma target 3.0

            // The Core.hlsl file contains definitions of frequently used HLSL
            // macros and functions, and also contains #include references to other
            // HLSL files (for example, Common.hlsl, SpaceTransforms.hlsl, etc.).
            // https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
                half4 _Color;
            CBUFFER_END

            // The structure definition defines which variables it contains.
            // This example uses the Attributes structure as an input structure in
            // the vertex shader.
            struct Attributes
            {
                // The positionOS variable contains the vertex positions in object
                // space.
                float4 positionOS : POSITION;
            };

            struct Varyings
            {
                // The positions in this struct must have the SV_POSITION semantic.
                float4 positionCS : SV_POSITION;
            };            

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                VertexPositionInputs vertexPositionInput = GetVertexPositionInputs(IN.positionOS.xyz);
                OUT.positionCS = vertexPositionInput.positionCS;
                return OUT;
            }
         
            float4 frag(Varyings IN) : SV_Target
            {
                return _Color;
            }
            ENDHLSL
        }
    }
}