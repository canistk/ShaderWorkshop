Shader "Kit/Universal Render Pipeline/URPUnlitShaderTransparent"
{
    Properties
    {
        _BgColor("Background", color) = (0.0,0.0,0.0,0.5)
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
            Color[_BgColor]
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
            Color[_Color]
        }
    }
}