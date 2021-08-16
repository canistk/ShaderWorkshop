Shader "Kit/Universal Render Pipeline/ScannerEffectSS"
{
    Properties
    {
        _MainTex("Texture", 2D) = "white" {}
        [HDR]_PulseColor("Pulse Color", color) = (1,1,1,1)
        _DimColor("Dim Color", color) = (1,1,1,1)
        

        _Origin("Origin Point of scanner", vector) = (0,0,0,0)
        _Margin("Margin", float) = 0
        _Radius("Min radius", float) = 5
        _EdgeSize ("EdgeSize", float) = 0.3
        _ScanDistance("Scanable distance", float) = 10
        _fallOffDistance("Fall off distance", float) = 20
        // _unity_ProjectionToWorld("Camera Matrix", float4x4) = ((0,0,0,0),(0,0,0,0),(0,0,0,0),(0,0,0,0))

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

            // due to using ddx() & ddy()
            #pragma target 3.0

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
                float4          _Origin;
                float           _Margin;
                float           _Radius;
                float           _EdgeSize;
                float           _ScanDistance;
                float           _fallOffDistance;
                float4x4        _unity_ProjectionToWorld;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS   : POSITION;
            };

            struct Varyings
            {
                float4 positionHCS   : SV_POSITION;
            };

            float invLerp(float from, float to, float value)
            {
                return (value - from) / (to - from);
            }

            real GetSceneDepth(float2 screenUV)
            {
                // Sample the depth from the Camera depth texture.
                // Reconstruct the world space positions.
#if UNITY_REVERSED_Z
                real depth = SampleSceneDepth(screenUV);
#else
                // Adjust z to match NDC for OpenGL
                real depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(screenUV));
#endif
                return depth;
            }

            half4 GenDebugDepth(real depth, float2 screenUV)
            {
                float3 worldPos = ComputeWorldSpacePosition(screenUV, depth, UNITY_MATRIX_I_VP);
                // The following part creates the checkerboard effect.
                // Scale is the inverse size of the squares.
                uint scale = 1;
                // Scale, mirror and snap the coordinates.
                uint3 worldIntPos = uint3(abs(worldPos.xyz * scale));
                // Divide the surface into squares. Calculate the color ID value.
                bool white = ((worldIntPos.x) & 1) ^ (worldIntPos.y & 1) ^ (worldIntPos.z & 1);
                // Color the square based on the ID value (black or white).
                return white ? half4(1, 1, 1, 1) : half4(.1, .1, .1, 1);
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
                real depth = GetSceneDepth(screenUV);
                // Reconstruct the world space positions.
                float3 worldPos = ComputeWorldSpacePosition(screenUV, depth, UNITY_MATRIX_I_VP);
                return worldPos;
            }

            // The fragment shader definition.            
            float4 frag(Varyings IN) : SV_Target
            {
                if (_Margin < 0.0001)
                    discard;
                float2 screenUV = IN.positionHCS.xy / _ScaledScreenParams.xy;

                real depth = GetSceneDepth(screenUV);

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
                float staticAlpha = saturate((maxRadius - distance) / maxRadius);
                float pulseAlpha = frac(pulseU);
                float scanableDistance = 1 - smoothstep(_ScanDistance - _Radius, _ScanDistance, distance);
                float fallOffDistance = 1 - smoothstep(_ScanDistance - _Radius, max(_ScanDistance, _fallOffDistance), _Margin);
                float fadeInnerCircle = smoothstep(_Radius - _EdgeSize, _Radius, distance);
                float alpha = fadeInnerCircle * scanableDistance* fallOffDistance * saturate(staticAlpha + pulseAlpha);
                if (alpha < 0.0001)
                    discard; // why we had inverse color.

                // Try reconstruct normal - SO EXPENSIVE !!
                // ref : https://forum.unity.com/threads/world-normal-from-scene-depth.1063625/
                // get view space position at 1 pixel offsets in each major direction
                float di = 1.0;
                float3 wsPos_l = GetWorldPos(screenUV + float2(-di, 0.0));
                float3 wsPos_r = GetWorldPos(screenUV + float2( di, 0.0));
                float3 wsPos_d = GetWorldPos(screenUV + float2( 0.0,-di));
                float3 wsPos_u = GetWorldPos(screenUV + float2( 0.0, di));
 
                // get the difference between the current and each offset position
                float3 l = worldPos - wsPos_l;
                float3 r = wsPos_r - worldPos;
                float3 d = worldPos - wsPos_d;
                float3 u = wsPos_u - worldPos;
 
                // pick horizontal and vertical diff with the smallest z difference
                float3 h = length(l) < length(r) ? l : r;
                float3 v = length(d) < length(u) ? d : u;
 
                // get view space normal from the cross product of the two smallest offsets
                float3 viewNormal = normalize(cross(h, v));
 
                // transform normal from view space to world space
                float3 WorldNormal = mul((float3x3)UNITY_MATRIX_VP, viewNormal);
                float tmp = dot(WorldNormal, mul((float3x3)UNITY_MATRIX_VP,float3(0,0,1)));
                return float4(saturate(-tmp), 0,0,1);

                // Color
                float4 pulse = tex2D(_MainTex, pulseUV) * _PulseColor;
                float4 dim = tex2D(_MainTex, staticUV) * _DimColor;
                float3 combie = saturate(dim.rgb + pulse.rgb * pulseAlpha);

                return float4(combie, alpha);
            }
            ENDHLSL
        }
    }
}