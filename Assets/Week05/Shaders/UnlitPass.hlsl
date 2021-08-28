#ifndef CUSTOM_UNLIT_PASS_INCLUDED
#define CUSTOM_UNLIT_PASS_INCLUDED
float4 UnlitPassVertex (float3 positionOS: POSITION) :SV_POSITION
{
    return float4(positionOS, 1.0);
}

float4 UnlitPassFragment () : SV_TARGET
{
    return 0.0;
}
#endif