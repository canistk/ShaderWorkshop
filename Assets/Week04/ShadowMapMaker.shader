Shader "hidden/Kit/Universal Render Pipeline/ShadowMapMaker"
{
    Properties
    {
    }

    SubShader
    {
        // https://docs.unity3d.com/Manual/SL-SubShaderTags.html
        Tags {
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
            "RenderPipeline" = "UniversalRenderPipeline"
            "ForceNoShadowCasting" = "True"
            "IgnoreProjector" = "True"
        }
        LOD 150
        ZWrite On

        Pass
        {
            Name "ForwardLit"
            Tags {
                "LightMode" = "UniversalForward"
            }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            

            CBUFFER_START(UnityPerMaterial)
                sampler2D   _MyShadowMap;
                float4x4    _MyShadowVP;
            CBUFFER_END

            struct Attributes
            {
                float4  positionOS  : POSITION;
                half3   normalOS    : NORMAL;
                float4  tangentOS   : TANGENT;
            };

            struct Varyings
            {
                float4 positionCS   : SV_POSITION;
                float3 positionWS   : TEXCOORD0;
                float4 normalWS_Depth : TEXCOORD1;
                half3 viewDirWS     : TEXCOORD2;
            };


            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
                OUT.positionCS = vertexInput.positionCS;
                OUT.positionWS = vertexInput.positionWS;
                // calculate here cheaper then fragment shader.
                OUT.viewDirWS = GetCameraPositionWS() - vertexInput.positionWS;
                float4 lightPosCS = mul(_MyShadowVP, vertexInput.positionWS);
                float d = lightPosCS.z / lightPosCS.w;
				if (UNITY_NEAR_CLIP_VALUE == -1) {
					d = d * 0.5 + 0.5;
				}
				#if UNITY_REVERSED_Z
					d = 1 - d;
				#endif

                OUT.normalWS_Depth = float4(normalInput.normalWS, d);
                return OUT;
            }

            float4 frag(Varyings IN) : SV_Target
            {
               return float4 (IN.normalWS_Depth.a, 0,0,1);
            }
            ENDHLSL
        }
    }
}