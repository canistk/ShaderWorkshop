Shader "Kit/Universal Render Pipeline/3DSoftMask"
{
    Properties
    {
        [HDR]_Color("_Color (default = 1,1,1,1)", color) = (1,1,1,1)
        _Margin("Margin", float) = 0
        _MinRange("Min Range", float) = 0
        _MaxRange("Max Range", float) = 2
        
        [Toggle(_DepthTexture)] _DepthTexture("Debug Depth Texture", Float) = 0
    }

    // The SubShader block containing the Shader code. 
    SubShader
    {
        // SubShader Tags define when and under which conditions a SubShader block or
        // a pass is executed.
        // https://docs.unity3d.com/Manual/SL-SubShaderTags.html
        Tags {
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalRenderPipeline"
            "Queue" = "Transparent"
            "ForceNoShadowCasting" = "True"
            "IgnoreProjector" = "True"
            "PreviewType" = "Plane"
            "DisableBatching" = "True"
        }
        LOD 100
        ZWrite on
        // ZTest Always
        Cull Off
        // https://docs.unity3d.com/Manual/SL-Blend.html
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            Name "Overlay"
            Tags {
                "LightMode" = "SRPDefaultUnlit"
            }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog

            // due to using ddx() & ddy()
            #pragma target 3.0
            #pragma shader_feature_local _DepthTexture

            // The Core.hlsl file contains definitions of frequently used HLSL
            // macros and functions, and also contains #include references to other
            // HLSL files (for example, Common.hlsl, SpaceTransforms.hlsl, etc.).
            // https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            // https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            // The DeclareDepthTexture.hlsl file contains utilities for sampling the
            // Camera depth texture.
            // https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            CBUFFER_START(UnityPerMaterial)
                sampler2D       _MainTex;
                float4          _MainTex_ST;
                float4          _Color;
                float           _Margin;
                float           _MinRange;
                float           _MaxRange;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS   : POSITION;
            };

            struct Varyings
            {
                float4 positionCS   : SV_POSITION;
            };

            real GetSceneDepth(float2 screenUV)
            {
                // Sample the depth from the Camera depth texture.
                // Reconstruct the world space positions.
#if UNITY_REVERSED_Z
                real depth = SampleSceneDepth(screenUV);
#else
                // Adjust z to match NDC for OpenGL
                real depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(screenUV));
#endif
                return depth;
            }

            half4 GenDebugDepth(real depth, float2 screenUV)
            {
                float3 worldPos = ComputeWorldSpacePosition(screenUV, depth, UNITY_MATRIX_I_VP);
                // The following part creates the checkerboard effect.
                // Scale is the inverse size of the squares.
                uint scale = 1;
                // Scale, mirror and snap the coordinates.
                uint3 worldIntPos = uint3(abs(worldPos.xyz * scale));
                // Divide the surface into squares. Calculate the color ID value.
                bool white = ((worldIntPos.x) & 1) ^ (worldIntPos.y & 1) ^ (worldIntPos.z & 1);
                // Color the square based on the ID value (black or white).
                return white ? half4(1, 1, 1, 1) : half4(.1, .1, .1, 1);
            }

            // The vertex shader definition with properties defined in the Varyings 
            // structure. The type of the vert function must match the type (struct)
            // that it returns.
            Varyings vert(Attributes IN)
            {
                // Declaring the output object (OUT) with the Varyings struct.
                Varyings OUT;
                VertexPositionInputs vertexPositionInput = GetVertexPositionInputs(IN.positionOS.xyz);
                OUT.positionCS = vertexPositionInput.positionCS;

                // To support VR ?
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);
                return OUT;
            }

            // The fragment shader definition.            
            float4 frag(Varyings IN) : SV_Target
            {
                // To calculate the UV coordinates for sampling the depth buffer,
                // divide the pixel location by the render target resolution
                // _ScaledScreenParams.
                float2 screenUV = IN.positionCS.xy / _ScaledScreenParams.xy;
                real depth = GetSceneDepth(screenUV);
#if _DepthTexture
                return GenDebugDepth(depth, screenUV);
#endif

                float selfDepth = IN.positionCS.z;// / IN.positionCS.w;

                // Reconstruct the world space positions.
                float3 worldPos = ComputeWorldSpacePosition(screenUV, depth, UNITY_MATRIX_I_VP);
                float3 selfPos = ComputeWorldSpacePosition(screenUV, selfDepth, UNITY_MATRIX_I_VP);
                float3 forward = worldPos - selfPos;
                float distance = length(forward);
                
                // Hard edge
                //float range = step(_Margin + _MaxRange, distance) - step(_Margin + _MinRange, distance);
                // Sofe edge
                float range = smoothstep(_Margin + _MinRange, _Margin + _MaxRange, distance);
                return float4(_Color.rgb, range);
            }
            ENDHLSL
        }
    }
}