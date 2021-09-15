Shader "Kit/Week07/GPU Particle"
{
    Properties
    {
        // _MainTex ("Texture", 2D) = "white" {}
        [HDR] _Color ("Tint", Color) = (0, 0, 0, 1)
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
        }
        LOD 100
        // Blend one OneMinusDstAlpha
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            CBUFFER_START(UnityPerMaterial)
                half4   _Color;
            CBUFFER_END

            struct Particle
            {
                float3 position;
                float3 scale;
                float3 velocity;
                float4 color;
                float lifetime;
            };
            StructuredBuffer<Particle> myParticles;
            
            StructuredBuffer<float3> myPosition;
            StructuredBuffer<float3> myVelocity;

            StructuredBuffer<int> myTriangles;
            StructuredBuffer<float3> myVertices;

            struct MeshData
            {
                uint    vertexId    : SV_VERTEXID;
                uint    instanceID  : SV_INSTANCEID;
            };

            struct v2f
            {
                float4  positionCS  : SV_POSITION;
                float4  color       : COLOR;
            };

            v2f vert (MeshData IN)
            {
                v2f OUT;
                // float pivotWS = myPosition[IN.instanceID];
                float pivotWS = myParticles[IN.instanceID].position;
                float3 scale = myParticles[IN.instanceID].scale;
                float3 velocity = myParticles[IN.instanceID].velocity;
                float4 color = myParticles[IN.instanceID].color;
                float lifetime = myParticles[IN.instanceID].lifetime;


                int index = myTriangles[IN.vertexId];
                float3 vertexOS = myVertices[index] * scale;
                float3 vertexWS = mul(UNITY_MATRIX_M, float4(vertexOS, 1));
                float3 positionWS = pivotWS + vertexWS;
                OUT.positionCS = mul(UNITY_MATRIX_VP, float4(positionWS, 1));
                OUT.color = color;
                return OUT;
            }

            float4 frag (v2f IN) : SV_Target
            {
                //return float4(0,0,0,1);
                return IN.color;
            }
            ENDHLSL
        }
    }
}
