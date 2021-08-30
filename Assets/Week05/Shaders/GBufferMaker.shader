Shader "hidden/GBufferMaker"
{
    SubShader
    {
        // https://docs.unity3d.com/Manual/SL-SubShaderTags.html
        Tags {
        }
        LOD 100

        Pass
        {
            Name "GBuffer"
            Tags {
                "LightMode" = "GBuffer"
            }
            ZWrite Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // #pragma target 3.0
            // https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            // https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.core/ShaderLibrary/SpaceTransforms.hlsl


            CBUFFER_START(UnityPerMaterial)
            CBUFFER_END

            struct Attributes
            {
                float4  positionOS  : POSITION;
                half3   normalOS    : NORMAL;
                float4  tangentOS   : TANGENT;
            };

            struct Varyings
            {
                float4 positionCS              : SV_POSITION;
                float3 positionWS               : TEXCOORD2;
                half3 normalWS                  : TEXCOORD3;
            };


            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
                OUT.positionCS = vertexInput.positionCS;
                OUT.positionWS = vertexInput.positionWS;
                OUT.normalWS = normalInput.normalWS;
                return OUT;
            }

            struct GBuffer
            {
                float3 positionWS   : SV_Position;
                float3 normalWS     : NORMAL;
                //float4 albedo       : COLOR;
                //float4 specular     : COLOR;
            };
            GBuffer frag(Varyings IN) : SV_Target
            {
                GBuffer G;
                G.positionWS = IN.positionWS;
                G.normalWS = IN.normalWS * 0.5 + 0.5;
                //G.albedo = float4(IN.positionWS, 1);
                //G.specular = 0;
                return G;
            }
            ENDHLSL
        }
        
    }
}