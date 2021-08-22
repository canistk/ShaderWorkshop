Shader "Kit/Universal Render Pipeline/Lit With Color Shadow"
{
    Properties
    {
        _MainTex("Texture", 2D) = "white" {}
        _Color("Color", color) = (0.5,0.5,0.5,0.5)

        _GlassTex("Texture", 2D) = "white" {}

        [IntRange]_MaxLightSrc("Max light source", Range(0,8)) = 0
        [Toggle] _DebugShadow("Debug shadow", float) = 0
        [Toggle(_ReadLight)] _ReadLight("Read Light", float) = 0
        [Toggle] _FlipLight("Debug Flip Light", float) = 0
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
            
            #pragma shader_feature_local _ReadLight
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
                sampler2D       _GlassTex;
                float4x4        _LightMatrixLocalToWorld;
                float4x4        _GlassMatrixLocalToWorld;
                float4x4        _GlassMatrixWorldToLocal;
                
                float4          _MainTex_ST;
                float4          _Color;

                float4          _LightColor;
                float4          _LightSetting; // x = Range, y = Intensity, z = Inner angle, w = outter angle

                float           _MaxLightSrc;
                float           _DebugShadow;
                float           _FlipLight;
                int             _HadGlass; // _GlassTex
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

/***
            // http://www.kittehface.com/2020/08/
            float DistanceAttenuation(float distanceSqr, half2 distanceAttenuation)
            {
                // Reconstruct the light range from the Unity shader arguments
                float lightRangeSqr = rcp(distanceAttenuation.x);

            #if !SHADER_HINT_NICE_QUALITY
                lightRangeSqr = -1.0 * lightRangeSqr / 0.36;
            #endif

                // Calculate the distance attenuation to approximate the built-in Unity curve
                return rcp(1 + 25 * distanceSqr / lightRangeSqr);
            }
***/

            Light CustomLight(half4 lightPosWS, half3 spotLightDirection,
                float3 positionWS, half3 normalWS, half3 color,
                float range, half intensity, half innerAngle, half outerAngle)
            {
                //float4 lightPosWS = mul(lightMatrixL2W, float4(0,0,0,1));
                //half3 spotLightDirection = mul((float3x3)lightMatrixL2W, float3(0,0,1));

                half3 lightVector = lightPosWS.xyz - positionWS * lightPosWS.w;
                half distanceSqr = max(dot(lightVector, lightVector), 0.00001);
                half3 lightDirection = half3(lightVector * rsqrt(distanceSqr)); // rsqrt(x) = 1 / sprt(x), 
                // lightDirection can be rewrite in 
                // lightVector * 1 / sqrt(distanceSqr)
                // lightVector / distance,
                // it's normalize when vector divide by it's length.
                // as same as this > half3 lightDirection = normalize(lightVector);

                
                // Distance attenuation
                // U3D Doc said :
                // We use a shared distance attenuation for additional directional and puctual lights
                // for directional lights attenuation will be 1
                //half lightAtten = rcp(distanceSqr); // O'Really ?
                //half lightAtten = 10.0 / length(lightPosWS.xyz - positionWS);
                //half lightAtten = 10.0 / range;
                //https://forum.unity.com/threads/point-light-range-is-very-low.764705/
                // lightAtten = 1, work for realtime light, 
                // In order to support lightmap, we need.
                // https://docs.unity3d.com/2020.1/Documentation/Manual/ProgressiveLightmapper-CustomFallOff.html?_ga=2.97184669.388907518.1629382485-1416679152.1573397245&_gl=1*5kejq0*_ga*MTQxNjY3OTE1Mi4xNTczMzk3MjQ1*_ga_1S78EFL1W5*MTYyOTU2NTA2Mi42OS4xLjE2Mjk1NjUxNzMuMjI.
                // https://zhuanlan.zhihu.com/p/87602137
                // http://www.kittehface.com/2020/08/
                // distanceAttenuation.x = assume is (r) range
                // distanceAttenuation.y = (1.0 / (fadeDistanceSqr - lightRangeSqr))
                // distanceAttenuation.z = (-lightRangeSqr / (fadeDistanceSqr - lightRangeSqr)
                // distanceAttenuation.w = 1.0 // to keep spot fade calculation from affecting the other light types
                // https://catlikecoding.com/unity/tutorials/scriptable-render-pipeline/lights/
                half lightAtten = sqrt(distanceSqr);
                half lightRangeSqr = max(range * range, 0.00001);
                half fadeDistanceSqr = 0.8 * 0.8 * lightRangeSqr; // the distance to start fade
                half fadeRangeSqr = (fadeDistanceSqr - lightRangeSqr);
                half oneOverFadeRangeSqr = 1.0 / fadeRangeSqr;
                half lightRangeSqrOverFadeRangeSqr = -lightRangeSqr / fadeRangeSqr;
                half oneOverLightRangeSqr = 1.0 / lightRangeSqr;
                
#if SHADER_HINT_NICE_QUALITY
                half factor = distanceSqr * oneOverLightRangeSqr; // Notes: mobile || switch should use "oneOverFadeRangeSqr" instead of "oneOverLightRangeSqr"
                half smoothFactor = saturate(1.0h - factor * factor);
                smoothFactor = smoothFactor * smoothFactor;
#else
                half smoothFactor = distanceSqr * (1.0 / fadeRangeSqr) + (-lightRangeSqr / fadeRangeSqr);
#endif
                smoothFactor = saturate(smoothFactor);
                half distanceAttenuation = lightAtten * smoothFactor;


                // Spot Attenuation
                // with a linear falloff can be defined as
                // (SdotL - cosOuterAngle) / (cosInnerAngle - cosOuterAngle)
                half cosInnerAngle = cos(innerAngle); // close to 1, cos angle should between 0~1, which mean 0~90 degree
                half cosOuterAngle = cos(outerAngle); // smaller then innerAngle.
                
                half flipDebug = (_FlipLight - 0.5) * 2.0; // toggle -1 & 1
                half SdotL = dot(spotLightDirection, lightDirection * flipDebug); // BUG : dirty fix by flip direction.
                // cut off the light behind, since dot inverse vector = -1
#if false
                half invAngleRange = 1.0 / max(cosInnerAngle - cosOuterAngle, 0.001);
                half AngleAtten = saturate(SdotL * invAngleRange + (-cosOuterAngle * invAngleRange));
                half AngleAttenuation = (AngleAtten * AngleAtten);
#else
                half AngleAttenuation = saturate((SdotL - cosOuterAngle) / (cosInnerAngle - cosOuterAngle));
#endif
                
                float diffuse = saturate(dot(normalWS, lightDirection));
                float fallOff = diffuse / distanceSqr; // 1 / (distance * distance)

                Light light;
                light.direction = spotLightDirection;
                light.color = color * fallOff;
                light.distanceAttenuation = intensity * distanceAttenuation * AngleAttenuation;
                light.shadowAttenuation = 1.0;
                // uint layerMask = DEFAULT_LIGHT_LAYERS;
                return light;
            }

            half4 IntersectPointOnPlane(half3 origin, half3 direction, half maxDistance,
                Light light,
                half3 quadPosWS, half3 quadNormal,
                half4x4 quadMatrixWorldToLocal, sampler2D quadTex)
            {
                half denominator = -dot(quadNormal, direction); // reverse to intersect
			    if (denominator > 1e-6) // avoid too close to 0, float point error.
			    {
				    half distance = dot(quadNormal, origin - quadPosWS) / denominator;
				    if (0.0 < distance && distance <= maxDistance)
				    {
                        half3 hitPosWS = origin + direction * distance;
                        // Assume it's Quad, and PositionOS == UV.
                        // Convert to local space.
                        half4 gPosOS = mul(quadMatrixWorldToLocal, half4(hitPosWS,1));
                        if (-0.5 <= gPosOS.x && gPosOS.x <= 0.5 &&
                            -0.5 <= gPosOS.y && gPosOS.y <= 0.5)
                        {
                            half2 uv = half2(gPosOS.xy + 0.5);
                            half4 color = tex2D(quadTex, uv);
                            half3 finColor = color.rgb * light.color * light.distanceAttenuation;
                            return half4(finColor, color.a);
                        }
				    }
			    }
                return half4(0,0,0,0);
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
                half3 lightColor = CalcBlinnPhong(GetMainLight(shadowCoord), IN.normalWS);
                
#if _ReadLight
                // Fake light session
                half4 lightPosWS = mul(_LightMatrixLocalToWorld, half4(0,0,0,1));
                half3 spotLightDirection = mul((half3x3)_LightMatrixLocalToWorld, half3(0,0,1));
                Light fakeLight = CustomLight(lightPosWS, spotLightDirection, IN.positionWS, IN.normalWS, (half3)_LightColor, _LightSetting.x, _LightSetting.y, _LightSetting.z, _LightSetting.w);
                lightColor.rgb += CalcBlinnPhong(fakeLight, IN.normalWS);
                // Fake light session - End

                // Fake Glass session
                if (_HadGlass == 1)
                {
                    half3 glassPosWS = mul(_GlassMatrixLocalToWorld, half4(0,0,0,1));
                    half3 glassFacing = mul((half3x3)_GlassMatrixLocalToWorld, half3(0,0,1));

                    half3 toLightVector = lightPosWS.xyz - IN.positionWS;
                    half toLightDistanceSqr = max(dot(toLightVector, toLightVector), 0.00001);
                    half toLightDistance = sqrt(toLightDistanceSqr);
                    half3 toLightDirection = half3(toLightVector * rsqrt(toLightDistanceSqr));
                    
                    half withInSpot = dot(toLightDirection, spotLightDirection);
                    if (withInSpot < 0)
                    {
                        half4 gColor = IntersectPointOnPlane(IN.positionWS.xyz, toLightDirection, toLightDistance, fakeLight, glassPosWS, glassFacing, _GlassMatrixWorldToLocal, _GlassTex);
                        gColor += IntersectPointOnPlane(IN.positionWS.xyz, toLightDirection, toLightDistance, fakeLight, glassPosWS, -glassFacing, _GlassMatrixWorldToLocal, _GlassTex);
                        lightColor += gColor.rgb * gColor.a;
                    }
                }
                // Fake Glass session - End
#endif

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
                return (1-_DebugShadow) * float4(lightColor.rgb * orgColor.rgb, 1) +
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