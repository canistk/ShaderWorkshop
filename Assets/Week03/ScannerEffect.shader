Shader "Kit/Universal Render Pipeline/ScannerEffect"
{
    Properties
    {
        _MainTex("Texture", 2D) = "white" {}
        [Toggle(_FlipColor)] _FlipColor("Flip color", float) = 0
        [HDR]_Color("_Color (default = 1,1,1,1)", color) = (1,1,1,1)

        _Origin("Origin Point of scanner", vector) = (0,0,0,0)
        _Margin("Margin", float) = 0
        _MinRange("Min Range", float) = 0
        _MaxRange("Max Range", float) = 2

        [Toggle(_DepthTexture)] _DepthTexture("Debug Depth Texture", Float) = 0

        [Header(Blending)]
        // https://docs.unity3d.com/ScriptReference/Rendering.BlendMode.html
        [Enum(UnityEngine.Rendering.BlendMode)]_SrcBlend("_SrcBlend (default = SrcAlpha)", Float) = 5 // 5 = SrcAlpha
        [Enum(UnityEngine.Rendering.BlendMode)]_DstBlend("_DstBlend (default = OneMinusSrcAlpha)", Float) = 10 // 10 = OneMinusSrcAlpha
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
            Blend[_SrcBlend][_DstBlend]
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
            // https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
            CBUFFER_START(UnityPerMaterial)
                sampler2D       _MainTex;
                float4          _MainTex_ST;
                //sampler2D     _CameraOpaqueTexture;
                //sampler2D     _CameraDepthTexture;
                float4          _Color;
                float4          _Origin;
                float           _Margin;
                float           _MinRange;
                float           _MaxRange;
                float           _FlipColor;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS   : POSITION;
            };

            struct Varyings
            {
                float4 positionCS   : SV_POSITION;
                float4 screenPos    : TEXCOORD0;
                float4 viewRayOS    : TEXCOORD1;
                float4 cameraPosOS  : TEXCOORD2;
            };

            float4 invLerp(float4 from, float4 to, float4 value)
            {
                return (value - from) / (to - from);
            }

            float4 remap(float4 origFrom, float4 origTo, float4 targetFrom, float4 targetTo, float4 value)
            {
                float4 rel = invLerp(origFrom, origTo, value);
                return lerp(targetFrom, targetTo, rel);
            }

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
                
                // prepare depth texture's screen space UV
                OUT.screenPos = ComputeScreenPos(OUT.positionCS);
                // get "camera to vertex" ray in View space
                float3 viewRay = vertexPositionInput.positionVS;
                // [important note]
                //=========================================================
                // "viewRay z division" must do in the fragment shader, not vertex shader! (due to rasteriazation varying interpolation's perspective correction)
                // We skip the "viewRay z division" in vertex shader for now, and store the division value into varying o.viewRayOS.w first, 
                // we will do the division later when we enter fragment shader
                // viewRay /= viewRay.z; //skip the "viewRay z division" in vertex shader for now
                OUT.viewRayOS.w = viewRay.z;//store the division value to varying o.viewRayOS.w
                //=========================================================

                // unity's camera space is right hand coord(negativeZ pointing into screen), we want positive z ray in fragment shader, so negate it
                viewRay *= -1;
                // it is ok to write very expensive code in decal's vertex shader, 
                // it is just a unity cube(4*6 vertices) per decal only, won't affect GPU performance at all.
                float4x4 ViewToObjectMatrix = mul(UNITY_MATRIX_I_M, UNITY_MATRIX_I_V);
                // transform everything to object space(decal space) in vertex shader first, so we can skip all matrix mul() in fragment shader
                OUT.viewRayOS.xyz = mul((float3x3)ViewToObjectMatrix, viewRay);
                OUT.cameraPosOS.xyz = mul(ViewToObjectMatrix, float4(0,0,0,1)).xyz;
                // hard code 0 or 1 can enable many compiler optimization

                // To support VR ?
                //UNITY_SETUP_INSTANCE_ID(IN);
                //UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

                return OUT;
            }

            // The fragment shader definition.            
            float4 frag(Varyings IN) : SV_Target
            {
                // [important note]
                //========================================================================
                // now do "viewRay z division" that we skipped in vertex shader earlier.
                IN.viewRayOS.xyz /= IN.viewRayOS.w;
                // Canis Note: viewRay projected from view to object space and lerp result.
                //========================================================================

                // To calculate the UV coordinates for sampling the depth buffer,
                // divide the pixel location by the render target resolution
                // _ScaledScreenParams.
                // float2 screenUV = IN.positionCS.xy / _ScaledScreenParams.xy;
                float2 screenUV = IN.screenPos.xy / IN.screenPos.w; // Canis Note. what is screenPos.w ? from ComputeScreenPos(). width ?

                // When not include "DeclareOpaqueTexture.hlsl"
                // after include hlsl "_CameraOpaqueTexture will be redefine in "TEXTURE2D_X" tex2D will not able to read that.
                // float4 scenecolor = tex2D(_CameraOpaqueTexture, screenUV); 
                
                real depth = GetSceneDepth(screenUV);
#if _DepthTexture
                return GenDebugDepth(depth, screenUV);
#endif

                float sceneDepthVS = LinearEyeDepth(depth,_ZBufferParams);

                // scene depth in any space = rayStartPos + rayDir * rayLength
                // here all data in ObjectSpace(OS) or DecalSpace
                // be careful, viewRayOS is not a unit vector, so don't normalize it, it is a direction vector which view space z's length is 1
                float3 decalSpaceScenePos = IN.cameraPosOS.xyz + IN.viewRayOS.xyz * sceneDepthVS;

                // Reconstruct the world space positions.
                float3 worldPos = ComputeWorldSpacePosition(screenUV, depth, UNITY_MATRIX_I_VP);

                //float selfDepth = IN.positionCS.z;// / IN.positionCS.w;
                //float3 selfPos = ComputeWorldSpacePosition(screenUV, selfDepth, UNITY_MATRIX_I_VP);

                float3 forward = worldPos - _Origin;
                float distance = length(forward);
                
                // Hard edge
                // float range = step(_Margin + _MinRange, distance) - step(_Margin + _MaxRange, distance);
                // Sofe edge
                float range = smoothstep(_Margin + _MinRange, _Margin + _MaxRange, distance);
                
                
                float3 objForward = float3(0,0,1);
                float angleDot = dot(objForward, normalize(forward));
                //float angle = acos(angleDot)/3.14159/2;

                float t = frac(range);

                float2 uv = float2(angleDot,t) * _MainTex_ST.xy + _MainTex_ST.zw;
                float4 col = tex2D(_MainTex, uv);
                col = abs(col - _FlipColor);
                return float4(col.rgb * _Color.rgb, col.a);
            }
            ENDHLSL
        }
    }
}