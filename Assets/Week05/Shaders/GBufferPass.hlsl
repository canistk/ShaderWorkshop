#ifndef CUSTOM_GBuffer_PASS_INCLUDED
#define CUSTOM_GBuffer_PASS_INCLUDED
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);

UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
	UNITY_DEFINE_INSTANCED_PROP(float4, _BaseMap_ST)
	UNITY_DEFINE_INSTANCED_PROP(float4, _BaseColor)
UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

struct Attributes
{
    float4  positionOS  : POSITION;
    half3   normalOS    : NORMAL;
    float4  tangentOS   : TANGENT;
    float2  baseUV      : TEXCOORD0;
};

struct Varyings
{
    float4  positionCS   : SV_POSITION;
    float2  baseUV       : VAR_BASE_UV;
    float3  positionWS   : TEXCOORD2;
    half3   normalWS     : TEXCOORD3;
};

struct GBuffer
{
    float4 positionWS   : SV_TARGET0;
    float4 normalWS     : SV_TARGET1;
    float4 albedo       : SV_TARGET2;
};

Varyings GBufferPassVertex (Attributes IN)
{
    Varyings OUT;
    VertexPositionInputs vertexInput = GetVertexPositionInputs(IN.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
    OUT.positionCS = vertexInput.positionCS;
    OUT.positionWS = vertexInput.positionWS;
    float4 baseST = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseMap_ST);
	OUT.baseUV = IN.baseUV * baseST.xy + baseST.zw;
    OUT.normalWS = normalInput.normalWS;
    return OUT;
}

GBuffer GBufferPassFragment (Varyings IN)
{
    float4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, IN.baseUV);
    float4 baseColor = UNITY_ACCESS_INSTANCED_PROP(UnityPerMaterial, _BaseColor);
    
    GBuffer G;
    G.positionWS = float4(IN.positionWS, 1);
    G.normalWS = float4(IN.normalWS, 0);
    G.albedo = baseMap * baseColor;
    return G;
}
#endif