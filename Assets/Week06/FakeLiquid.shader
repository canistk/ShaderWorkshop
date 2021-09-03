// Study Ref : https://www.patreon.com/posts/shader-part-2-24996282
Shader "Kit/Week06/Fake Liquid"
{
    Properties
    {
        _MainTex("Texture", 2D) = "white" {}
        _Color("Color", color) = (0.5,0.5,0.5,0.5)

        _FillAmount ("Fill Amount", Range(-10,10)) = 0.0
        [HideInInspector] _WobbleX ("WobbleX", Range(-1,1)) = 0.0
		[HideInInspector] _WobbleZ ("WobbleZ", Range(-1,1)) = 0.0
        _TopColor ("Top Color", Color) = (1,1,1,1)
		_FoamColor ("Foam Line Color", Color) = (1,1,1,1)
        _Rim ("Foam Line Width", Range(0,0.1)) = 0.0    
		_RimColor ("Rim Color", Color) = (1,1,1,1)
	    _RimPower ("Rim Power", Range(0,10)) = 0.0

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
            "RenderType" = "Geometry"
            "RenderPipeline" = "UniversalRenderPipeline"
            "Queue" = "Geometry"
            "DisableBatching" = "True"
            "UniversalMaterialType" = "Lit"
        }
        LOD 300
        Zwrite On
        Cull Off
        AlphaToMask On

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
                float4          _TopColor;
                float4          _RimColor;
                float4          _FoamColor;
                float4          _Tint;

                float           _NormalWeight;
                float           _FillAmount;
                float           _WobbleX;
                float           _WobbleZ;
                float           _Rim;
                float           _RimPower;

                float           _MaxLightSrc;
                float           _DebugShadow;
                float           _DebugNormal;
            CBUFFER_END
            

            half4 RotateAroundYInDegrees (half4 vertex, half degrees)
            {
                // const float PI = 3.141592653589793238462;
                // half alpha = degrees * 3.14159 / 180;
                half alpha = degrees * 0.0174532925199433;
                half sina, cosa;
                sincos(alpha, sina, cosa);
                half2x2 m = half2x2(cosa, sina, -sina, cosa);
                return half4(vertex.yz , mul(m, vertex.xz)).xzyw ;				
            }

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
                float4 positionCS               : SV_POSITION;
                float3 positionWS               : TEXCOORD0;
                half2 uv                        : TEXCOORD1;
                half3 normalWS                  : TEXCOORD3;
                half3 tangentWS                 : TEXCOORD4;
                half3 binormalWS                : TEXCOORD6;
                float fillEdge                  : TEXCOORD7;
                float3 viewDir                  : COLOR;

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
                half3 worldPos = vertexInput.positionWS;
                OUT.positionWS = worldPos;
                OUT.positionCS = vertexInput.positionCS;
                OUT.normalWS = normalInput.normalWS;
                OUT.tangentWS = mul((half3x3)UNITY_MATRIX_M, IN.tangentOS.xyz);
                half3 binormalOS = cross(IN.normalOS, IN.tangentOS.xyz);
                OUT.binormalWS = mul((half3x3)UNITY_MATRIX_M, binormalOS);

                // rotate it around XY
			    half3 worldPosX= RotateAroundYInDegrees(half4(worldPos,0),360);
                // rotate around XZ
                half3 worldPosZ = half3(worldPos.y, worldPos.z, worldPos.x);
                // combine rotations with worldPos, based on sine wave from script
                half3 worldPosAdjusted = worldPos + (worldPosX  * _WobbleX) + (worldPosZ * _WobbleZ);
                // how high up the liquid is
                OUT.fillEdge = worldPosAdjusted.y + _FillAmount;
                half3 vs = vertexInput.positionVS.xyz;
                OUT.viewDir = normalize(vs);
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

            float4 frag(Varyings IN, half facing : VFACE) : SV_Target
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
                half4 normalDebug = half4(normalWSM * 0.5 + 0.5, 1.0);

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
                half4 col = half4(lightColor.rgb * orgColor.rgb, 1.0);

                // rim light
		        half dotProduct = 1 - pow(dot(IN.normalWS, IN.viewDir), _RimPower);
                half4 RimResult = smoothstep(0.5, 1.0, dotProduct);
                RimResult *= _RimColor;

                // foam edge
                half4 foam = ( step(IN.fillEdge, 0.5) - step(IN.fillEdge, (0.5 - _Rim)))  ;
                half4 foamColored = foam * (_FoamColor * 0.9);
                // rest of the liquid
                half4 result = step(IN.fillEdge, 0.5) - foam;
                half4 resultColored = result * col;
                // both together, with the texture
                half4 finalResult = resultColored + foamColored;				
                finalResult.rgb += RimResult;
 
                // color of backfaces/ top
                half4 topColor = _TopColor * (foam + result);
                //VFACE returns positive for front facing, negative for backfacing
                half4 fakeLiquidColor = facing > 0 ? finalResult: topColor;

                return lerp(lerp(fakeLiquidColor, addShadowDebug, _DebugShadow), normalDebug, _DebugNormal);
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