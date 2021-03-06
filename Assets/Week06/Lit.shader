Shader "Kit/Week06/Lit V2" // color, shadow, normal
{
    Properties
    {
        _MainTex("Texture", 2D) = "white" {}
        _Color("Color", color) = (0.5,0.5,0.5,0.5)

        _NormalMap("Normal Map", 2D) = "white" {}
        _NormalWeight ("Normal Map Weight", float) = 1

        [IntRange]_MaxLightSrc("Max light source", Range(0,8)) = 0
        [Toggle] _DebugNormal("Debug normal", float) = 0
        [Toggle] _DebugShadow("Debug shadow", float) = 0
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

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D(_NormalMap);
            SAMPLER(sampler_NormalMap);
            CBUFFER_START(UnityPerMaterial)
                float4          _Color;

                float4          _LightColor;
                float4          _LightSetting; // x = Range, y = Intensity, z = Inner angle, w = outter angle

                float           _NormalWeight;
                float           _MaxLightSrc;
                float           _DebugShadow;
                float           _DebugNormal;
            CBUFFER_END

            struct Attributes
            {
                float4  positionOS  : POSITION;
                half3   normalOS    : NORMAL;
                float4  tangentOS   : TANGENT;
                half2  uv          : TEXCOORD0;
                // half2  lightmapUV  : TEXCOORD1;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                half2 uv                       : TEXCOORD0;
                //DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);
                float3 positionWS               : TEXCOORD2;
                half3 normalWS                  : TEXCOORD3;

                half3 tangentWS                 : TEXCOORD4;
                half3 binormalWS                : TEXCOORD6;
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
                half NdotL = saturate(dot(normalWS * _NormalWeight, -normalize(light.direction)));
                half3 attenuatedLightColor = light.color * (light.distanceAttenuation * light.shadowAttenuation);
                half3 lightColor = attenuatedLightColor;
                //#if defined(_SPECGLOSSMAP) || defined(_SPECULAR_COLOR)
                //half smoothness = exp2(10 * surfaceData.smoothness + 1);
                //lightColor += LightingSpecular(attenuatedLightColor, light.direction, inputData.normalWS, inputData.viewDirectionWS, half4(surfaceData.specular, 1), smoothness);
                //#endif
                return lightColor * NdotL;
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
                //half3 viewDirWS = GetCameraPositionWS() - vertexInput.positionWS; // calculate here cheaper then fragment shader.
                //half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
                //half fogFactor = ComputeFogFactor(vertexInput.positionCS.z);

                OUT.uv = IN.uv;
                OUT.positionWS = vertexInput.positionWS;
                OUT.positionCS = vertexInput.positionCS;
                OUT.normalWS = normalInput.normalWS;
                OUT.tangentWS = mul((half3x3)UNITY_MATRIX_M, IN.tangentOS.xyz);
                half3 binormalOS = cross(IN.normalOS, IN.tangentOS.xyz);
                OUT.binormalWS = mul((half3x3)UNITY_MATRIX_M, binormalOS);
                return OUT;
            }


            half3 UnpackNormalDXT5nm (half4 packednormal)
            {
               half3 normal;
               normal.xy = packednormal.wy * 2 - 1;
            #if defined(SHADER_API_FLASH)
               // Flash does not have efficient saturate(), and dot() seems to require an extra register.
               normal.z = sqrt(1 - normal.x*normal.x - normal.y * normal.y);
            #else
               normal.z = sqrt(1 - saturate(dot(normal.xy, normal.xy)));
            #endif
               return normal;
            }
 
            half3 UnpackNormal(half4 packednormal)
            {
            #if (defined(SHADER_API_GLES) || defined(SHADER_API_GLES3)) && defined(SHADER_API_MOBILE)
               return packednormal.xyz * 2 - 1;
            #else
               return UnpackNormalDXT5nm(packednormal);
            #endif
            }

            float4 frag(Varyings IN) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);
                float4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv);
                float4 orgColor = texColor * _Color;
                
                // Normal map
                // 'TBN' transforms the world space into a tangent space
				// we need its inverse matrix
				// Tip : An inverse matrix of orthogonal matrix is its transpose matrix
                float3x3 TBN = transpose(float3x3(
                    normalize(IN.tangentWS),
                    normalize(IN.binormalWS),
                    normalize(IN.normalWS)));

                float4 tangentNormal = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, IN.uv);
                float3 normalWSM = mul(TBN, UnpackNormal(tangentNormal));
                if (_DebugNormal > 0)
                    return float4(normalWSM * 0.5 + 0.5, 1.0);

                float4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
                half3 lightColor = CalcBlinnPhong(GetMainLight(shadowCoord), normalWSM);
                
                half4 addShadowDebug = half4(1,1,1,1);
                int cnt = _MaxLightSrc; // GetAdditionalLightsCount());
                for (int i=0; i<cnt; i++)
                {
                    // Directional lights store direction in lightPosition.xyz and have .w set to 0.0.
                    // This way the following code will work for both directional and punctual lights.
                    Light light = GetAdditionalPerObjectLight(i, IN.positionWS);
                    light.shadowAttenuation = CalcAdditionalShadow(IN.uv, i, IN.positionWS);
                    addShadowDebug *= light.shadowAttenuation;
                    lightColor.rgb += CalcBlinnPhong(light, normalWSM);
                }
                return (1.0-_DebugShadow) * float4(lightColor.rgb * orgColor.rgb, 1.0) +
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