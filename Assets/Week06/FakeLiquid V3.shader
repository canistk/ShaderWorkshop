// Study Ref : https://www.patreon.com/posts/shader-part-2-24996282
// Study Ref : https://developer.nvidia.com/gpugems/gpugems2/part-ii-shading-lighting-and-shadows/chapter-19-generic-refraction-simulation
Shader "Kit/Week06/Fake Liquid V3"
{
    Properties
    {
        [header(Liquid)]
        _FoamTex("Foam Texture", 2D) = "white" {}
        _TopColor ("Top Color", Color) = (1,1,1,1)
        
		_FoamColor ("Foam Line Color", Color) = (1,1,1,1)
        _Rim ("Foam Line Width", Range(0,0.1)) = 0.0    

        _MainTex("Texture", 2D) = "white" {}
        _Color("Color", color) = (0.5,0.5,0.5,0.5)

        [header(State)]
        _LiquidLevel ("Liquid level(WS)", Range(-10,10)) = 0.0
        _Impurities ("Impurities to reflect light", Range(0,1)) = 0.5

        [header(Style)]
		_RimColor ("Rim Color", Color) = (1,1,1,1)
	    _RimPower ("Rim Power", Range(-1,1)) = 0.0
        _Refractive ("Refractive", Range(-1,1)) = 0.0
        _BumpWeight ("Bump", vector) = (0.2, 0.2, 1.0, 0.5)

        [HideInInspector] _WobbleX ("WobbleX", Range(-1,1)) = 0.0
		[HideInInspector] _WobbleZ ("WobbleZ", Range(-1,1)) = 0.0
        [HideInInspector] _RotationHotfix ("Adjust Liquid level during rotation", float) = 0.0
    }

    SubShader
    {
        // https://docs.unity3d.com/Manual/SL-SubShaderTags.html
        Tags {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalRenderPipeline"
            // "Queue" = "Geometry"
            "Queue" = "Transparent-498" // Remark, -499 will not display in CameraOpaqueTexture
            "DisableBatching" = "True"
            // "UniversalMaterialType" = "Lit"
        }
        LOD 300
        Zwrite On

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_instancing
            
            //#pragma multi_compile_fog
            #pragma target 3.0

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

            TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
            TEXTURE2D(_FoamTex); SAMPLER(sampler_FoamTex);
            TEXTURE2D(_CameraOpaqueTexture); SAMPLER(sampler_CameraOpaqueTexture);
            CBUFFER_START(UnityPerMaterial)
                half4   _Color;
                half4   _TopColor;
                half4   _RimColor;
                half4   _FoamColor;
                half4   _BumpWeight; // xyz-control bump vector, w control the twit between 2 refractive sampler

                half    _Impurities;
                half    _Rim;
                half    _RimPower;
                half    _Refractive;

                half    _LiquidLevel;
                half    _RotationHotfix;
                half    _WobbleX;
                half    _WobbleZ;
            CBUFFER_END
            

            half4 RotateAroundYInDegrees (half4 vertex, half degrees)
            {
                // const half PI = 3.141592653589793238462;
                // half alpha = degrees * 3.14159 / 180;
                half alpha = degrees * 0.0174532925199433;
                half sina, cosa;
                sincos(alpha, sina, cosa);
                half2x2 m = half2x2(cosa, sina, -sina, cosa);
                return half4(vertex.yz , mul(m, vertex.xz)).xzyw ;				
            }

            struct Attributes
            {
                half4  positionOS  : POSITION;
                half3   normalOS    : NORMAL;
                half4  tangentOS   : TANGENT;
                half2  uv          : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                half4 positionCS               : SV_POSITION;
                half3 positionWS               : TEXCOORD0;
                half2 uv                        : TEXCOORD2;
                half3 normalWS                  : TEXCOORD3;
                half fillEdge                  : TEXCOORD4;
                half3 viewDir                  : COLOR;

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
                half NdotL = saturate(dot(normalWS, -normalize(light.direction)));
                half3 attenuatedLightColor = light.color * (light.distanceAttenuation * light.shadowAttenuation);
                half3 lightColor = attenuatedLightColor;
                //#if defined(_SPECGLOSSMAP) || defined(_SPECULAR_COLOR)
                //half smoothness = exp2(10 * surfaceData.smoothness + 1);
                //lightColor += LightingSpecular(attenuatedLightColor, light.direction, inputData.normalWS, inputData.viewDirectionWS, half4(surfaceData.specular, 1), smoothness);
                //#endif
                return lightColor * NdotL;
            }

            // Lighting.hlsl > GetAdditionalLight(uint i, half3 positionWS, half4 shadowMask)
            half CalcAdditionalShadow(half2 uv, int lightIndex, half3 positionWS)
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
                // VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);

                half3 worldPos = mul(UNITY_MATRIX_M, IN.positionOS).xyz; // vertexInput.positionWS;
                
                // rotate it around XY
			    half3 worldPosX = RotateAroundYInDegrees(half4(worldPos,0),360).xyz;
                // rotate around XZ
                half3 worldPosZ = half3(worldPos.y, worldPos.z, worldPos.x);
                // combine rotations with worldPos, based on sine wave from script
                half3 worldPosAdjusted = worldPos + (worldPosX  * _WobbleX) + (worldPosZ * _WobbleZ);
                // how high up the liquid is
                OUT.fillEdge = worldPosAdjusted.y;
                half3 viewDirWS = GetCameraPositionWS() - worldPos; // calculate here cheaper then fragment shader.
                OUT.viewDir = normalize(viewDirWS);

                // OUT.positionWS = worldPos;
                // Project the upper empty bottle area to liquid level.
                // since we bias world up we can calculate it by float(y-axis)
                half edge = _LiquidLevel + _RotationHotfix;
                half pFlag = step(worldPosAdjusted.y, edge); // 1 = vertex need to project
                half pDistance = worldPosAdjusted.y - edge;
                half3 projectedPosWS = worldPosAdjusted;
                projectedPosWS.y -= pDistance;

                OUT.normalWS = lerp(normalize(worldPosAdjusted), normalInput.normalWS, pFlag);
                OUT.positionWS = lerp(projectedPosWS, worldPos, pFlag);
                OUT.positionCS = mul(UNITY_MATRIX_VP, half4(OUT.positionWS, 1));
                OUT.uv = lerp(frac(half2(worldPos.x, worldPos.z) * 10), IN.uv, pFlag);
                return OUT;
            }

            half4 frag(Varyings IN, half facing : VFACE) : SV_Target
            {
                half edge = _LiquidLevel + _RotationHotfix;
                half4 fillMask = step(IN.fillEdge, edge);
                //if (fillMask.a < 1.0)
                //    discard;

                UNITY_SETUP_INSTANCE_ID(IN);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);
                
                // --- Light ---
                half4 shadowCoord = TransformWorldToShadowCoord(IN.positionWS);
                half3 lightColor = CalcBlinnPhong(GetMainLight(shadowCoord), IN.normalWS);
                
                int cnt = GetAdditionalLightsCount();
                for (int i = 0; i < cnt; i++)
                {
                    // Directional lights store direction in lightPosition.xyz and have .w set to 0.0.
                    // This way the following code will work for both directional and punctual lights.
                    Light light = GetAdditionalPerObjectLight(i, IN.positionWS);
                    light.shadowAttenuation = CalcAdditionalShadow(IN.uv, i, IN.positionWS);
                    lightColor.rgb += CalcBlinnPhong(light, IN.normalWS);
                }
                half3 ImpuritiesLight = lightColor * _Impurities;

                // rim light
		        // half dotProduct = 1 - pow(abs(dot(IN.normalWS, normalize(IN.viewDir))), _RimPower);
                half dotProduct = dot(IN.normalWS, IN.viewDir);
                half Rim = 1.0 - smoothstep(_RimPower, 1.0, dotProduct);
                half3 RimResult = (_RimColor.rgb * _RimColor.a) * Rim;

                // To calculate the UV coordinates for sampling the depth buffer,
                // divide the pixel location by the render target resolution
                // _ScaledScreenParams.
                half2 screenUV = IN.positionCS.xy / _ScaledScreenParams.xy;
                half4 sceneColor = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, screenUV);

                // Scene Refractive
                // https://en.wikibooks.org/wiki/Cg_Programming/Unity/Curved_Glass
                //half refractiveIndex = 1.5;
                //half3 refractedDir = refract(normalize(IN.viewDir), normalize(IN.normalWS), 1.0 / refractiveIndex);
                //return texCUBE(_Cube, refractedDir);

                // Scene Refractive Screen Space - cheaper
                // https://developer.nvidia.com/gpugems/gpugems2/part-ii-shading-lighting-and-shadows/chapter-19-generic-refraction-simulation
                half refractive = smoothstep(_Refractive, 1.0, dotProduct); //Rim * 0.5 + 0.5; //1.0 - (2.0 - Rim - 1.0);
                half3 vEye = normalize(IN.viewDir);
                half3 bumpNormal = lerp(IN.normalWS, vEye, refractive);
                half3 vBump = normalize(bumpNormal * _BumpWeight.xyz); // suggested : half3(0.2, 0.2, 1.0));
                half4 vRefrA = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, screenUV + vBump.xy * _BumpWeight.w); // to control how twist of the image. suggested : 0.5);
	            half4 vRefrB = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, screenUV - vBump.xy);      // Mask occluders from refraction map
                
                // Reflection, require cube map.
                // half LdotN = dot(bumpNormal, vEye);
                // half3 vReflect = 2.0 * LdotN * vBump.xyz - vEye;      // Reflection vector coordinates used for environmental mapping    
                // half4 vEnvMap = tex2D(cubeTex3, (vReflect.xy + 1.0) * 0.5);      // Compute projected coordinates and add perturbation 
	            half4 disolvedSceneColor = lerp(vRefrA, vRefrB, refractive); // Compute Fresnel term      
                // return disolvedSceneColor; // debug

                // --- Liquid stuff
                // foam surface layer
                half4 emptyBottleMask = 1.0 - fillMask;
                half4 foamTex = SAMPLE_TEXTURE2D(_FoamTex, sampler_FoamTex, IN.uv);
                half4 topFoamColor = foamTex * _TopColor;
                topFoamColor.rgb = lerp(vRefrA.rgb, topFoamColor.rgb, topFoamColor.a) + ImpuritiesLight;
                half4 topFoamColored = emptyBottleMask * topFoamColor;

                // foam edge
                half4 foamMask = (fillMask - step(IN.fillEdge, (edge - _Rim)));
                half4 foamEdgeColor = foamTex * _FoamColor;
                foamEdgeColor.rgb = lerp(vRefrA.rgb, foamEdgeColor.rgb, foamEdgeColor.a) + ImpuritiesLight;
                half4 foamEdgeColored = foamMask * foamEdgeColor;

                // rest of the liquid                
                half4 liquidMask = fillMask - foamMask;
                half4 texColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv) * _Color;
                half3 liquidColor = lerp(disolvedSceneColor.rgb, texColor.rgb, texColor.a) + ImpuritiesLight;
                half4 liquidColored = liquidMask * half4(liquidColor, 1);

                //return emptyBottleMask * half4(1,0,0,1) +
                //        foamMask * half4(0,0,1,1) +
                //        liquidMask * half4(0,1,0,1);

                // both together, with the texture
                half4 finalResult = liquidColored + foamEdgeColored + topFoamColored;
                finalResult.rgb += fillMask.rgb * RimResult;
                
                return finalResult;
            }
            ENDHLSL
        }
    }
}