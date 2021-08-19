Shader "Kit/Universal Render Pipeline/Lit With Color Shadow"
{
    Properties
    {
        _MainTex("Texture", 2D) = "white" {}
        _Color("Color", color) = (0.5,0.5,0.5,0.5)
    }

    // The SubShader block containing the Shader code. 
    SubShader
    {
        // SubShader Tags define when and under which conditions a SubShader block or
        // a pass is executed.
        // https://docs.unity3d.com/Manual/SL-SubShaderTags.html
        Tags {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
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
            //#pragma multi_compile_fog

            // due to using ddx() & ddy()
            // #pragma target 3.0

            // The Core.hlsl file contains definitions of frequently used HLSL
            // macros and functions, and also contains #include references to other
            // HLSL files (for example, Common.hlsl, SpaceTransforms.hlsl, etc.).
            // https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl
            // #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            // https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl
            // #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            
            
            // https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            // https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl
            // #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"

            // https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/Shaders/LitForwardPass.hlsl
            // #include "Packages/com.unity.render-pipelines.universal/Shaders/LitForwardPass.hlsl"
            // https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl


            CBUFFER_START(UnityPerMaterial)
                sampler2D       _MainTex;
                float4          _MainTex_ST;
                float4          _Color;
            CBUFFER_END

            struct Attributes
            {
                float4  positionOS  : POSITION;
                half3   normalOS    : NORMAL;
                float4  tangentOS   : TANGENT;
                float2  uv          : TEXCOORD0;
                // float2  lightmapUV  : TEXCOORD1;
                //UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float2 uv                       : TEXCOORD0;
                //DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);
                float3 positionWS               : TEXCOORD2;
                half3 normalWS                  : TEXCOORD3;
                //half3 viewDirWS                 : TEXCOORD4;
                //half4 fogFactorAndVertexLight   : TEXCOORD6; // x: fogFactor, yzw: vertex light
                //float4 shadowCoord              : TEXCOORD7;
                float4 positionCS               : SV_POSITION;
                //UNITY_VERTEX_INPUT_INSTANCE_ID
                //UNITY_VERTEX_OUTPUT_STEREO
            };

            /**
            // InputData.hlsl, https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl
            InputData CustomInputData(Varyings IN)
            {
                InputData OUT;
                OUT.positionWS = IN.positionWS;
                // OUT.positionCS = IN.positionCS;
                OUT.normalWS = IN.normalWS;
                OUT.viewDirectionWS = IN.viewDirWS;
                OUT.shadowCoord = IN.shadowCoord;
                OUT.fogCoord = IN.fogFactorAndVertexLight.x;

                OUT.vertexLighting = 0;
                // half3 VertexLighting(float3 positionWS, half3 normalWS)
                // https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl

                OUT.bakedGI = 0;
                // OUT.normalizedScreenSpaceUV = float2
                // OUT.shadowMask = half4
                // OUT.tangentToWorld = (float3x3)UNITY_MATRIX_M;
                return OUT;
            }
            ***/
            // RealtimeLights.hlsl
            // https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/RealtimeLights.hlsl
            //struct Light
            //{
            //    half3   direction;
            //    half3   color;
            //    half    distanceAttenuation;
            //    half    shadowAttenuation;
            //    uint    layerMask;
            //};

            // LitInput.hlsl > SurfaceData.hlsl
            // https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceData.hlsl
            //SurfaceData U3DSurface(Surface surface)
            //{
            //    SurfaceData OUT;
            //    OUT.albedo = surface.color;
            //    OUT.specular = 0;
            //    OUT.metallic = 0;
            //    OUT.smoothness = 0;
            //    OUT.normalTS = surface.normal;
            //    OUT.emission = 0;
            //    OUT.occlusion = 0;
            //    OUT.alpha = surface.alpha;
            //    OUT.clearCoatMask = 0;
            //    OUT.clearCoatSmoothness = 0;
            //    return OUT;
            //}

            half3 CalcBlinnPhong(Light light, half3 albedo, half3 normalWS)
            {
                // Lighting.hlsl > CalculateBlinnPhong() > LightingLambert()
                half NdotL = saturate(dot(normalWS, light.direction));
                half3 attenuatedLightColor = light.color * (light.distanceAttenuation * light.shadowAttenuation);
                half3 lightColor = attenuatedLightColor * albedo;
                //#if defined(_SPECGLOSSMAP) || defined(_SPECULAR_COLOR)
                //half smoothness = exp2(10 * surfaceData.smoothness + 1);
                //lightColor += LightingSpecular(attenuatedLightColor, light.direction, inputData.normalWS, inputData.viewDirectionWS, half4(surfaceData.specular, 1), smoothness);
                //#endif
                return lightColor;
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);
                VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
                //half3 viewDirWS = GetCameraPositionWS() - vertexInput.positionWS; // calculate here cheaper then fragment shader.
                //half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
                //half fogFactor = ComputeFogFactor(vertexInput.positionCS.z);

                OUT.uv = IN.uv;
                OUT.normalWS = normalInput.normalWS;
                //OUT.viewDirWS = viewDirWS;
                //OUT.fogFactorAndVertexLight = half4(fogFactor, vertexLight);
                OUT.positionWS = vertexInput.positionWS;
                //OUT.shadowCoord = GetShadowCoord(vertexInput);
                OUT.positionCS = vertexInput.positionCS;
                return OUT;
            }

            float4 frag(Varyings IN) : SV_Target
            {
                float4 texColor = tex2D(_MainTex, IN.uv * _MainTex_ST.xy + _MainTex_ST.zw);
                float4 orgColor = texColor * _Color;

                half3 col = CalcBlinnPhong(GetMainLight(), orgColor.rgb, IN.normalWS);
                
                int cnt = 8; // GetAdditionalLightsCount();
                for (int i=0; i<cnt; i++)
                {
                    // Directional lights store direction in lightPosition.xyz and have .w set to 0.0.
                    // This way the following code will work for both directional and punctual lights.
                    //float3 lightVector = lightPositionWS.xyz - positionWS * lightPositionWS.w;
                    //float distanceSqr = max(dot(lightVector, lightVector), HALF_MIN);
                    //half3 lightDirection = half3(lightVector * rsqrt(distanceSqr));
                    //half attenuation = half(DistanceAttenuation(distanceSqr, distanceAndSpotAttenuation.xy) * AngleAttenuation(spotDirection.xyz, lightDirection, distanceAndSpotAttenuation.zw));
                    Light light = GetAdditionalPerObjectLight(i, IN.positionWS);
                    col.rgb += CalcBlinnPhong(light, orgColor.rgb, IN.normalWS);
                }
                return float4(col, 1);
            }
            ENDHLSL
        }
    }
}