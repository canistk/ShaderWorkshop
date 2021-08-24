Shader "hidden/Kit/Universal Render Pipeline/ShadowMapMaker"
{
    SubShader
    {
        // https://docs.unity3d.com/Manual/SL-SubShaderTags.html
        Tags {
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
            "RenderPipeline" = "UniversalRenderPipeline"
            "ForceNoShadowCasting" = "True"
            "IgnoreProjector" = "True"
        }

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

            struct Attributes
            {
                float4  positionOS  : POSITION;
            };

            struct Varyings
            {
                float4 positionHCS   : SV_POSITION;
            };

            float GetSceneDepth(float2 screenUV)
            {
                // Sample the depth from the Camera depth texture.
                // Reconstruct the world space positions.
#if UNITY_REVERSED_Z
                float depth = SampleSceneDepth(screenUV);
#else
                // Adjust z to match NDC for OpenGL
                float depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(screenUV));
#endif
                return depth;
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = IN.positionOS;
                return OUT;
            }

            float4 frag(Varyings IN) : SV_Target
            {
                float2 screenUV = IN.positionHCS.xy / _ScaledScreenParams.xy;
                float depth = GetSceneDepth(screenUV);
                return float4 (depth, 0, 0, 1);
            }
            ENDHLSL
        }
    }
}