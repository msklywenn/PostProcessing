Shader "Hidden/PostProcessing/DeferredFog"
{
    HLSLINCLUDE

        #pragma multi_compile __ FOG_LINEAR FOG_EXP FOG_EXP2
        #include "../StdLib.hlsl"
        #include "Fog.hlsl"

        TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
        TEXTURE2D_SAMPLER2D(_CameraDepthTexture, sampler_CameraDepthTexture);

        #define SKYBOX_THREASHOLD_VALUE 0.9999

        struct AttributesFog
        {
            float4 vertex : POSITION;
            float4 texcoord : TEXCOORD0;
            float4 texcoord1 : TEXCOORD1;
        };

        struct VaryingsFogFade
        {
            VaryingsDefault deffault;
            float3 ray : TEXCOORD2;
        };

        VaryingsFogFade VertFogFade(AttributesFog v)
        {
            VaryingsFogFade o;

            AttributesDefault defAttribs;
            defAttribs.vertex = v.vertex;
            o.deffault = VertDefault(defAttribs);

            float _SkyRotation = FOG_SKYBOX_ROTATION;
            o.ray = RotateAroundYAxis(v.texcoord1.xyz, _SkyRotation);

            return o;
        }

        float4 Frag(VaryingsDefault i) : SV_Target
        {
            half4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoordStereo);

            float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.texcoordStereo);
            depth = Linear01Depth(depth);
            float dist = ComputeFogDistance(depth);
            half fog = 1.0 - ComputeFog(dist);

            return lerp(color, _FogColor, fog);
        }

        float4 FragExcludeSkybox(VaryingsDefault i) : SV_Target
        {
            half4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoordStereo);

            float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.texcoordStereo);
            depth = Linear01Depth(depth);
            float skybox = depth < SKYBOX_THREASHOLD_VALUE;
            float dist = ComputeFogDistance(depth);
            half fog = 1.0 - ComputeFog(dist);

            return lerp(color, _FogColor, fog * skybox);
        }

        float4 FragFadeToSkybox(VaryingsFogFade i) : SV_Target
        {
            half4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.deffault.texcoordStereo);

            float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.deffault.texcoordStereo);
            depth = Linear01Depth(depth);
            float dist = ComputeFogDistance(depth) - FOG_START;
            half fog = 1.0 - ComputeFog(dist);

            // Look up the skybox color.
            half3 skyColor = texCUBE(_SkyCubemap, i.ray);
            skyColor *= _FogColor.rgb * _FogColor.a * 4.59479380; // _FogColor.a contains exposure

            // Lerp between source color to skybox color with fog amount.
            half4 sceneColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.deffault.texcoordStereo);
            return lerp(sceneColor, half4(skyColor, 1), fog);
        }

    ENDHLSL

    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            HLSLPROGRAM
                #pragma vertex VertDefault
                #pragma fragment Frag
            ENDHLSL
        }

        Pass
        {
            HLSLPROGRAM
                #pragma vertex VertDefault
                #pragma fragment FragExcludeSkybox
            ENDHLSL
        }

        Pass
        {
            HLSLPROGRAM
                #pragma vertex VertFogFade
                #pragma fragment FragFadeToSkybox
            ENDHLSL
        }
    }
}
