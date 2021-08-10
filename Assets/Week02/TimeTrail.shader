Shader "Kit/Universal Render Pipeline/TimeTrail"
{
    Properties
    {
        _MainTex ("Main Texture", 2D) = "black" {}
        _SysTime("System Time", float) = 0
        _Min("Min", float) = 0.2
        _Max("Max", float) = 1
        _ExpandW("Expand Width Amount", float) = 1
        _ExpandY("Expand height Amount", float) = 1
    }

    SubShader
    {
        // https://docs.unity3d.com/Manual/SL-SubShaderTags.html
        Tags {
            "RenderType" = "Transparent"
            "Queue" = "Transparent" // Queue : { Background, Geometry, AlphaTest, Transparent, Overlay }
            "RenderPipeline" = "UniversalPipeline"
            // "DisableBatching" = "True"
        }
        LOD 100
        Cull Off
        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha
		
        Pass
        {
            HLSLPROGRAM
            // This line defines the name of the vertex shader. 
            #pragma vertex vert
            // This line defines the name of the fragment shader. 
            #pragma fragment frag
            // The Core.hlsl file contains definitions of frequently used HLSL
            // macros and functions, and also contains #include references to other
            // HLSL files (for example, Common.hlsl, SpaceTransforms.hlsl, etc.).
            // https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Input.hlsl"
            sampler2D _MainTex;
            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float _SysTime;
                float _Min;
                float _Max;
                float _ExpandW;
                float _ExpandY;
            CBUFFER_END
            
            float invLerp(float from, float to, float value) { return (value - from) / (to - from); }

            struct Attributes
            {
                // The positionOS variable contains the vertex positions in object
                // space.
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
                float4 color : COLOR;
            };

            struct Varyings
            {
                // The positions in this struct must have the SV_POSITION semantic.
                float4 positionCS : SV_POSITION;
                float4 color : COLOR;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                float3 localVector = IN.color.xyz;
                float spawnTime = IN.color.w;
                float threshold;
                if (_SysTime < _Min)
                    threshold = 0;
                else
                    threshold = saturate((_SysTime - spawnTime - _Min) / (_Max - _Min));

                float3 adjustedWS = TransformObjectToWorld(IN.vertex.xyz)
                    + (localVector * threshold)
                    + float3(0, threshold * _ExpandY, 0);
                float3 view = TransformWorldToView(adjustedWS);
                OUT.positionCS = mul(UNITY_MATRIX_P, float4(view,1));
                
                OUT.color = IN.color;
                OUT.normal = IN.normal;
                OUT.uv = IN.uv;
                return OUT;
            }

            float4 frag(Varyings IN) : SV_Target
            {
                // calculate UV
                float spawnTime = IN.color.w;
                float t = step(_SysTime - spawnTime, _Min);
                float ratio = saturate(1.0 - saturate(_SysTime - spawnTime - _Min) / (_Max- _Min));
                
                // Stay mesh unchange, before "Min", blend alpha after Min~Max
                float threshold = t + (1 - t) * ratio;
                float alpha = threshold;
                
                float4 col = tex2D(_MainTex, IN.uv * _MainTex_ST.xy + _MainTex_ST.zw);
                col.a = alpha;
                return col;
            }
            ENDHLSL
        }
    }
}