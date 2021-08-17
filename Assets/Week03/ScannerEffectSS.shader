Shader "Kit/Universal Render Pipeline/ScannerEffectSS"
{
    Properties
    {
        _MainTex("Texture", 2D) = "white" {}
        [HDR]_PulseColor("Pulse Color", color) = (1,1,1,1)
        [HDR]_DimColor("Dim Color", color) = (1,1,1,1)
        [HDR]_HighLightColor("Hight light Color", color) = (1,1,1,1)
        
        [Decal]
        _Origin("Origin Point of scanner", vector) = (0,0,0,0)
        _Margin("Margin", float) = 0
        _Radius("Min radius", float) = 5
        _EdgeSize ("EdgeSize", float) = 0.3
        _ScanDistance("Scanable distance", float) = 10
        _fallOffDistance("Fall off distance", float) = 20

        [Header(Sobel Edge)]
        _OutlineThickness ("Outline Thickness", float) = 3
        _OutlineDepthMultiplier ("Outline Depth Multiplier", float) = 0.15
        _OutlineDepthBias ("Outline Depth Bias", float) = 2

        [Header(Blending)]
        // https://docs.unity3d.com/ScriptReference/Rendering.BlendMode.html
        [Enum(UnityEngine.Rendering.BlendMode)]_SrcBlend("_SrcBlend (default = SrcAlpha)", Float) = 5 // 5 = SrcAlpha
        [Enum(UnityEngine.Rendering.BlendMode)]_DstBlend("_DstBlend (default = OneMinusSrcAlpha)", Float) = 10 // 10 = OneMinusSrcAlpha
    }

    // The SubShader block containing the Shader code. 
    SubShader
    {
        // SubShader Tags define when and under which conditions a SubShader block or
        // a pass is executed.
        // https://docs.unity3d.com/Manual/SL-SubShaderTags.html
        Tags {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalRenderPipeline"
        }
        LOD 100
        ZWrite Off
        // https://docs.unity3d.com/Manual/SL-Blend.html
        Blend[_SrcBlend][_DstBlend]
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // due to sampler
            #pragma target 3.5

            // The Core.hlsl file contains definitions of frequently used HLSL
            // macros and functions, and also contains #include references to other
            // HLSL files (for example, Common.hlsl, SpaceTransforms.hlsl, etc.).
            // https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            // https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            // The DeclareDepthTexture.hlsl file contains utilities for sampling the
            // Camera depth texture.
            // https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            CBUFFER_START(UnityPerMaterial)
                sampler2D       _MainTex;
                float4          _MainTex_ST;
                float4          _PulseColor;
                float4          _DimColor;
                float4          _HighLightColor;
                float4          _Origin;

                float           _Margin;
                float           _Radius;
                float           _EdgeSize;
                float           _ScanDistance;

                float           _fallOffDistance;
                float           _OutlineThickness;
                float           _OutlineDepthMultiplier;
                float           _OutlineDepthBias;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS   : POSITION;
            };

            struct Varyings
            {
                float4 positionHCS  : SV_POSITION;
            };

            float invLerp(float from, float to, float value)
            {
                return (value - from) / (to - from);
            }

            float GetSceneDepth(float2 screenUV)
            {
                // Sample the depth from the Camera depth texture.
                // Reconstruct the world space positions.
#if UNITY_REVERSED_Z
                float depth = SampleSceneDepth(screenUV);
#else
                // Adjust z to match NDC for OpenGL
                float depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(screenUV));
#endif
                return depth;
            }

            // The vertex shader definition with properties defined in the Varyings 
            // structure. The type of the vert function must match the type (struct)
            // that it returns.
            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                // In post process script, since we are that Camera, Object space == Clip space
                OUT.positionHCS = IN.positionOS;
                return OUT;
            }

            float3 GetWorldPos(float2 screenUV)
            {
                float depth = GetSceneDepth(screenUV);
                // Reconstruct the world space positions.
                float3 worldPos = ComputeWorldSpacePosition(screenUV, depth, UNITY_MATRIX_I_VP);
                return worldPos;
            }

            float3 GetViewPos(float2 screenUV)
            {
                float depth = GetSceneDepth(screenUV);
                float3 viewPos = ComputeViewSpacePosition(screenUV, depth, UNITY_MATRIX_I_P);
                return viewPos;
            }

            // Sobel Edge
            // ref : https://www.vertexfragment.com/ramblings/unity-postprocessing-sobel-outline/
            float SobelDepth(float2 screenUV, float thickness, float multiplier, float bias)
            {
                // get view space position at certain pixel offsets in each major direction
                float3 offset = float3(1.0 / _ScreenParams.x, 1.0 / _ScreenParams.y, 0.0) * thickness;

                float pos_c = GetViewPos(screenUV).z;
                float pos_l = GetViewPos(screenUV - offset.xz).z;
                float pos_r = GetViewPos(screenUV + offset.xz).z;
                float pos_d = GetViewPos(screenUV + offset.zy).z;
                float pos_u = GetViewPos(screenUV - offset.zy).z;
 
                // get the difference between the current and each offset position
                float u = abs(pos_u - pos_c);
                float d = abs(pos_d - pos_c);
                float l = abs(pos_l - pos_c);
                float r = abs(pos_r - pos_c);

                // calculate sobel difference.
                float sobelDepth = pow(abs((u+d+l+r) * multiplier), abs(bias));
                return sobelDepth;
            }

            float3 SobelNormal(float2 screenUV, float thickness, float multiplier, float bias)
            {
                // get view space position at certain pixel offsets in each major direction
                float3 offset = float3(1.0 / _ScreenParams.x, 1.0 / _ScreenParams.y, 0.0) * thickness;

                float3 pos_c = GetViewPos(screenUV);
                float3 pos_l = GetViewPos(screenUV - offset.xz);
                float3 pos_r = GetViewPos(screenUV + offset.xz);
                float3 pos_d = GetViewPos(screenUV + offset.zy);
                float3 pos_u = GetViewPos(screenUV - offset.zy);
 
                // get the difference between the current and each offset position
                float3 u = abs(pos_u - pos_c);
                float3 d = abs(pos_d - pos_c);
                float3 l = abs(pos_l - pos_c);
                float3 r = abs(pos_r - pos_c);

                return u+d+l+r;
                // calculate sobel difference.
                //float sobelDepth = pow(abs((u+d+l+r) * multiplier), abs(bias));
                //return sobelDepth;
            }

            // The fragment shader definition.            
            float4 frag(Varyings IN) : SV_Target
            {
                if (_Margin < 0.0001)
                    discard;
                float2 screenUV = IN.positionHCS.xy / _ScaledScreenParams.xy;

                float depth = GetSceneDepth(screenUV);

                // Reconstruct the world space positions.
                float3 worldPos = ComputeWorldSpacePosition(screenUV, depth, UNITY_MATRIX_I_VP);
                float distance = length(worldPos - _Origin.xyz);
                
                // Define edge
                float level = _Margin - max(0, _Radius + _EdgeSize);
                float minRadius = max(0, level + _Radius);
                float maxRadius = max(0, minRadius + _EdgeSize);

                // Pulse
                float y = 0.5;
                float pulseU = saturate(smoothstep(minRadius, maxRadius, distance));
                float2 pulseUV = float2(pulseU, y);
                float2 staticUV = float2(invLerp(minRadius, maxRadius, max(0, distance + level)), y) * _MainTex_ST.xy + _MainTex_ST.zw;
                
                // Alpha
                float staticAlpha = saturate((_Margin - distance) / _Margin);
                float pulseAlpha = frac(pulseU);
                float scanableDistance = 1 - smoothstep(_ScanDistance - _Radius, _ScanDistance, distance);
                float fallOffDistance = 1 - smoothstep(_ScanDistance - _Radius, max(_ScanDistance, _fallOffDistance), _Margin);
                float fadeInnerCircle = smoothstep(_Radius - _EdgeSize, _Radius, distance);
                float alpha = fadeInnerCircle * scanableDistance * fallOffDistance * saturate(staticAlpha + pulseAlpha);
                if (alpha < 0.0001)
                    discard; // why we had inverse color.
 
                float sobelDepth = SobelDepth(screenUV, _OutlineThickness, _OutlineDepthMultiplier, _OutlineDepthBias);
                //float3 sobelNormal = SobelNormal(screenUV, _OutlineThickness, _OutlineDepthMultiplier, _OutlineDepthBias);
                //return float4(sobelNormal, 1);

                // Color
                float4 pulse = tex2D(_MainTex, pulseUV) * _PulseColor;
                float4 dim = tex2D(_MainTex, staticUV) * _DimColor;
                float4 highLight = sobelDepth * _HighLightColor;
                // return float4(highLight.rgb,1);
                float3 combie = saturate(dim.rgb + highLight.rgb + pulse.rgb * pulseAlpha);
                
                return float4(combie, alpha);
            }
            ENDHLSL
        }
    }
}