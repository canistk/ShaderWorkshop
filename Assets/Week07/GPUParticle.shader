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
            
            StructuredBuffer<int> myTriangles;
            StructuredBuffer<float3> myVertices;

            StructuredBuffer<float3> myPositions, myScale, myVelocity;
            StructuredBuffer<float4> myColor;
            StructuredBuffer<float> myLifeTime;

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
                float3 pivotWS =    myPositions[IN.instanceID];
                float3 scale =      myScale[IN.instanceID];
                float3 velocity =   myVelocity[IN.instanceID];
                float4 color =      myColor[IN.instanceID];
                float lifetime =    myLifeTime[IN.instanceID];


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
                return IN.color;
            }
            ENDHLSL
        }
    }
}
