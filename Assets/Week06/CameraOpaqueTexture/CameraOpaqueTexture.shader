Shader "Kit/Universal Render Pipeline/Tools/CameraOpaqueTexture"
{
    Properties
    {
        _Color("_Color (default = 1,1,1,1)", color) = (1,1,1,1)
    }

    SubShader
    {
        // Draw after all opaque geometry
        Tags {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalRenderPipeline"
            "Queue" = "Transparent-499"
            "ForceNoShadowCasting" = "True"
            "IgnoreProjector" = "True"
            "PreviewType" = "Plane"
            "DisableBatching" = "True"
        }
        LOD 100
        ZWrite off

        Cull Off

        Pass
        {
            Name "Overlay"
            Tags {
                "LightMode" = "SRPDefaultUnlit"
            }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // The Core.hlsl file contains definitions of frequently used HLSL
            // macros and functions, and also contains #include references to other
            // HLSL files (for example, Common.hlsl, SpaceTransforms.hlsl, etc.).
            // https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            TEXTURE2D(_CameraOpaqueTexture); SAMPLER(sampler_CameraOpaqueTexture);
            CBUFFER_START(UnityPerMaterial)
            //sampler2D   _CameraOpaqueTexture;
            float4      _Color;
            CBUFFER_END

            struct Attributes
            {
                float3 positionOS : POSITION;
            };

            struct Varyings
            {
                float4 positionCS  : SV_POSITION;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.positionOS.xyz);
                OUT.positionCS = vertexInput.positionCS;
                // Or
                // OUT.positionCS = TransformObjectToHClip(IN.positionOS.xyz);

                return OUT;
            }

            float4 frag(Varyings IN) : SV_Target
            {
                // To calculate the UV coordinates for sampling the depth buffer,
                // divide the pixel location by the render target resolution
                // _ScaledScreenParams.
                float2 screenUV = IN.positionCS.xy / _ScaledScreenParams.xy;

                // Important : require to enable "Opaque texture" option in Quality setting or Camera.
                half4 sceneColor = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, screenUV) * _Color;
                // Or
                // half4 sceneColor = tex2D(_CameraOpaqueTexture, screenUV) * _Color;

                return sceneColor;
            }
            ENDHLSL
        }

    }
}