Shader "Kit/Universal Render Pipeline/ReadLight"
{
    Properties
    {
        _MainTex("Texture", 2D) = "white" {}
        _Color("Color", color) = (0.5,0.5,0.5,0.5)
        [IntRange]_MaxLightSrc("Max light source", Range(0,8)) = 0
        [Toggle] _DebugShadow("Debug shadow", int) = 0
    }

    SubShader
    {
        // https://docs.unity3d.com/Manual/SL-SubShaderTags.html
        Tags {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalRenderPipeline"
            "Queue" = "Geometry"
            "UniversalMaterialType" = "Lit"
        }
        LOD 300

        Pass
        {
            Name "ForwardLit"
            Tags {
                "LightMode" = "UniversalForward"
            }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ _RECEIVE_SHADOWS_OFF
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            //#pragma multi_compile_fog
            // #pragma target 3.0

            // The Core.hlsl file contains definitions of frequently used HLSL
            // macros and functions, and also contains #include references to other
            // HLSL files (for example, Common.hlsl, SpaceTransforms.hlsl, etc.).
            // https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            // https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl
            // #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            // https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            //#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            // https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl
            // #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            // https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/Shaders/LitForwardPass.hlsl
            // #include "Packages/com.unity.render-pipelines.universal/Shaders/LitForwardPass.hlsl"
            // https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl


            CBUFFER_START(UnityPerMaterial)
                sampler2D       _MainTex;
                float4          _MainTex_ST;
                float4          _Color;
                float           _MaxLightSrc;
                int             _DebugShadow;
            CBUFFER_END

            struct Attributes
            {
                float4  positionOS  : POSITION;
                half3   normalOS    : NORMAL;
                float4  tangentOS   : TANGENT;
                float2  uv          : TEXCOORD0;
                // float2  lightmapUV  : TEXCOORD1;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float2 uv                       : TEXCOORD0;
                //DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);
                float3 positionWS               : TEXCOORD2;
                half3 normalWS                  : TEXCOORD3;
                // half3 viewDirWS                 : TEXCOORD4;
                // half4 fogFactorAndVertexLight   : TEXCOORD6; // x: fogFactor, yzw: vertex light
                // float4 shadowCoord              : TEXCOORD7;
                float4 positionCS               : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            //**
            // InputData -> InputData.hlsl
            // https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl
            // SurfaceData -> LitInput.hlsl > SurfaceData.hlsl
            // https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceData.hlsl
            // Light -> Lighting.hlsl > RealtimeLights.hlsl
            // https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/RealtimeLights.hlsl
            //**/

            // Lighting.hlsl > CalculateBlinnPhong() > LightingLambert()
            half3 CalcBlinnPhong(Light light, half3 normalWS)
            {
                half NdotL = saturate(dot(normalWS, light.direction));
                half3 attenuatedLightColor = light.color * (light.distanceAttenuation * light.shadowAttenuation);
                half3 lightColor = attenuatedLightColor;
                //#if defined(_SPECGLOSSMAP) || defined(_SPECULAR_COLOR)
                //half smoothness = exp2(10 * surfaceData.smoothness + 1);
                //lightColor += LightingSpecular(attenuatedLightColor, light.direction, inputData.normalWS, inputData.viewDirectionWS, half4(surfaceData.specular, 1), smoothness);
                //#endif
                return lightColor;
            }

            // Lighting.hlsl > GetAdditionalLight(uint i, float3 positionWS, half4 shadowMask)
            half CalcAdditionalShadow(half2 uv, int lightIndex, float3 positionWS)
            {
                int perObjectLightIndex = GetPerObjectLightIndex(lightIndex);
#if USE_STRUCTURED_BUFFER_FOR_LIGHT_DATA
                half4 occlusionProbeChannels = _AdditionalLightsBuffer[perObjectLightIndex].occlusionProbeChannels;
#else
                half4 occlusionProbeChannels = _AdditionalLightsOcclusionProbes[perObjectLightIndex];
#endif
                half4 shadowMask = SAMPLE_SHADOWMASK(uv);
                half shadowAttenuation = AdditionalLightShadow(perObjectLightIndex, positionWS, shadowMask, occlusionProbeChannels);
                return shadowAttenuation;
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_TRANSFER_INSTANCE_ID(IN, OUT);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);
                VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
                half3 viewDirWS = GetCameraPositionWS() - vertexInput.positionWS; // calculate here cheaper then fragment shader.
                half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
                half fogFactor = ComputeFogFactor(vertexInput.positionCS.z);

                OUT.uv = IN.uv;
                OUT.normalWS = normalInput.normalWS;
                //OUT.viewDirWS = viewDirWS;
                //OUT.fogFactorAndVertexLight = half4(fogFactor, vertexLight);
                OUT.positionWS = vertexInput.positionWS;
                // OUT.shadowCoord = GetShadowCoord(vertexInput); // TransformWorldToShadowCoord(IN.positionWS)
                OUT.positionCS = vertexInput.positionCS;
                return OUT;
            }

            float4 frag(Varyings IN) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);
                float4 texColor = tex2D(_MainTex, IN.uv * _MainTex_ST.xy + _MainTex_ST.zw);
                float4 orgColor = texColor * _Color;
                
                float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
                half3 lightColor = orgColor.rgb * CalcBlinnPhong(GetMainLight(shadowCoord), IN.normalWS);
                
                half4 addShadowDebug = half4(1,1,1,1);
                int cnt = _MaxLightSrc; // GetAdditionalLightsCount());
                for (int i=0; i<cnt; i++)
                {
                    // Directional lights store direction in lightPosition.xyz and have .w set to 0.0.
                    // This way the following code will work for both directional and punctual lights.
                    Light light = GetAdditionalPerObjectLight(i, IN.positionWS);
                    light.shadowAttenuation = CalcAdditionalShadow(IN.uv, i, IN.positionWS);
                    addShadowDebug *= light.shadowAttenuation;
                    lightColor.rgb += CalcBlinnPhong(light, IN.normalWS);
                }
                return (1-_DebugShadow) * float4(lightColor.rgb, 1) +
                        (_DebugShadow) * addShadowDebug;
            }
            ENDHLSL
        }
        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Back

            HLSLPROGRAM
            #pragma only_renderers gles gles3 glcore d3d11
            #pragma target 2.0

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature_local_fragment _ALPHATEST_ON
            #pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }
        // https://illu.tistory.com/1407 + alpha test
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
}