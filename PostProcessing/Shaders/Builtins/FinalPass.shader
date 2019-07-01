Shader "Hidden/PostProcessing/FinalPass"
{
    HLSLINCLUDE

        #pragma multi_compile __ FXAA FXAA_LOW
        #pragma multi_compile __ FXAA_KEEP_ALPHA

        #pragma vertex VertUVTransform
        #pragma fragment Frag

        #include "../StdLib.hlsl"
        #include "../Colors.hlsl"
        #include "Dithering.hlsl"

#if defined(SHADER_API_SWITCH)
#define FXAA_PC_CONSOLE 1
#else
        #define FXAA_PC 1
#endif

        #if FXAA_KEEP_ALPHA
            // Luma hasn't been encoded in alpha
            #define FXAA_GREEN_AS_LUMA 1
        #else
            // Luma is encoded in alpha after the first Uber pass
            #define FXAA_GREEN_AS_LUMA 0
        #endif

        #if FXAA_LOW
            #define FXAA_QUALITY__PRESET 12
            #define FXAA_QUALITY_SUBPIX 1.0
            #define FXAA_QUALITY_EDGE_THRESHOLD 0.166
            #define FXAA_QUALITY_EDGE_THRESHOLD_MIN 0.0625
        #else
            #define FXAA_QUALITY__PRESET 28
            #define FXAA_QUALITY_SUBPIX 1.0
            #define FXAA_QUALITY_EDGE_THRESHOLD 0.063
            #define FXAA_QUALITY_EDGE_THRESHOLD_MIN 0.0312
        #endif

        #include "FastApproximateAntialiasing.hlsl"

        TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
        float4 _MainTex_TexelSize;

        float4 _FXAAConsoleCorner;
        float4 _FXAAConsoleRcpFrameOpt;
        float4 _FXAAConsoleRcpFrameOpt2;

        float4 Frag(VaryingsDefault i) : SV_Target
        {
            half4 color = 0.0;

            // Fast Approximate Anti-aliasing
            #if FXAA || FXAA_LOW
            {
                #if FXAA_HLSL_4 || FXAA_HLSL_5
                    FxaaTex mainTex;
                    mainTex.tex = _MainTex;
                    mainTex.smpl = sampler_MainTex;
                #else
                    FxaaTex mainTex = _MainTex;
                #endif

                float4 pospos = i.texcoord.xyxy + _FXAAConsoleCorner;
                color = FxaaPixelShader(
                    i.texcoord,                      // pos
                    pospos,                          // fxaaConsolePosPos
                    mainTex,                         // tex
                    mainTex,                         // fxaaConsole360TexExpBiasNegOne (unused)
                    mainTex,                         // fxaaConsole360TexExpBiasNegTwo (unused)
                    _MainTex_TexelSize.xy,           // fxaaQualityRcpFrame
                    _FXAAConsoleRcpFrameOpt,         // fxaaConsoleRcpFrameOpt
                    _FXAAConsoleRcpFrameOpt2,        // fxaaConsoleRcpFrameOpt2
                    0.0,                             // fxaaConsole360RcpFrameOpt2 (unused)
                    FXAA_QUALITY_SUBPIX,
                    FXAA_QUALITY_EDGE_THRESHOLD,
                    FXAA_QUALITY_EDGE_THRESHOLD_MIN,
                    8.0,                             // fxaaConsoleEdgeSharpness (8.0 = default, lower is softer)
                    0.125,                           // fxaaConsoleEdgeThreshold (0.125 = default, higher is sharper)
                    0.05,                            // fxaaConsoleEdgeThresholdMin (0.05 = default, > is faster with more aliasing)
                    0.0                              // fxaaConsole360ConstDir (unused)
                );

                #if FXAA_KEEP_ALPHA
                {
                    color.a = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoordStereo).a;
                }
                #else
                color.a = 1;
                #endif
            }
            #else
            {
                color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoordStereo);
            }
            #endif

#if !defined(SHADER_API_SWITCH)
            color.rgb = Dither(color.rgb, i.texcoord);
#endif
            return color;
        }

    ENDHLSL

    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            HLSLPROGRAM
                #pragma exclude_renderers gles vulkan switch

                #pragma multi_compile __ STEREO_INSTANCING_ENABLED STEREO_DOUBLEWIDE_TARGET
                #pragma target 5.0

            ENDHLSL
        }
    }

    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            HLSLPROGRAM
                #pragma exclude_renderers gles vulkan switch

                #pragma multi_compile __ STEREO_INSTANCING_ENABLED STEREO_DOUBLEWIDE_TARGET
                #pragma target 3.0

            ENDHLSL
        }
    }

    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            HLSLPROGRAM
                #pragma only_renderers gles

                #pragma multi_compile __ STEREO_INSTANCING_ENABLED STEREO_DOUBLEWIDE_TARGET
                #pragma target es3.0

            ENDHLSL
        }
    }

    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            HLSLPROGRAM
                #pragma only_renderers gles vulkan switch

                #pragma multi_compile __ STEREO_DOUBLEWIDE_TARGET //not supporting STEREO_INSTANCING_ENABLED
            ENDHLSL
        }
    }
}
