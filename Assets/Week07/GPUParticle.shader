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
        Blend SrcAlpha one
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
                // float3 scale;
                float3 velocity;
                float4 color;
                float lifetime;
            };
            StructuredBuffer<Particle> myParticles;
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
                // int vid = myTriangles[IN.vertexId];
                // float3 position = myVertices[vid];
                v2f OUT;
                float3 positionOS = myParticles[IN.instanceID].position;
                OUT.positionCS = mul(UNITY_MATRIX_VP, float4(positionOS, 1));
                return OUT;
            }

            float4 frag (v2f IN) : SV_Target
            {
                return IN.color;
            }
            ENDHLSL
        }
    }
}
