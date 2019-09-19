Shader "Hidden/PostProcessing/DeferredFog"
{
    HLSLINCLUDE

        #pragma multi_compile __ FOG_LINEAR FOG_EXP FOG_EXP2
        #include "../StdLib.hlsl"
        #include "Fog.hlsl"

        TEXTURE2D_SAMPLER2D(_CameraDepthTexture, sampler_CameraDepthTexture);

        #define SKYBOX_THRESHOLD_VALUE 0.9999

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

            float tanHalfFovX = 1 / unity_CameraProjection[0][0];
            float tanHalfFovY = 1 / unity_CameraProjection[1][1];
            float near = _ProjectionParams.y;
            float3 right = unity_WorldToCamera[0].xyz * near * tanHalfFovX;
            float3 top = unity_WorldToCamera[1].xyz * near * tanHalfFovY;
            float2 corner = v.vertex.xy;
#if UNITY_UV_STARTS_AT_TOP
            corner.y = -corner.y;
#endif
            float3 origin = unity_WorldToCamera[2].xyz * near;
            o.ray = origin + corner.x * right + corner.y * top;

            float _SkyRotation = FOG_SKYBOX_ROTATION;
            o.ray = RotateAroundYAxis(o.ray, _SkyRotation);

            return o;
        }

        float4 Frag(VaryingsDefault i) : SV_Target
        {
            float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.texcoordStereo);
            depth = Linear01Depth(depth);
            float dist = ComputeFogDistance(depth);
            half fog = 1.0 - ComputeFog(dist);

            return half4(_FogColor.rgb, fog);
        }

        float4 FragExcludeSkybox(VaryingsDefault i) : SV_Target
        {
            float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.texcoordStereo);
            depth = Linear01Depth(depth);
            float skybox = depth < SKYBOX_THRESHOLD_VALUE;
            float dist = ComputeFogDistance(depth);
            half fog = 1.0 - ComputeFog(dist);

            return half4(_FogColor.rgb, fog * skybox);
        }

        float4 FragFadeToSkybox(VaryingsFogFade i) : SV_Target
        {
            float depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.deffault.texcoordStereo);
            depth = Linear01Depth(depth);
            float dist = ComputeFogDistance(depth) - FOG_START;
            half fog = 1.0 - ComputeFog(dist);
            float skybox = depth > SKYBOX_THRESHOLD_VALUE;

            float blend = saturate(fog + skybox);
            if (blend <= 0.05)
                discard;

            // Look up the skybox color.
            half3 skyColor = texCUBE(_SkyCubemap, i.ray);
            skyColor *= _FogColor.rgb * _FogColor.a * 4.59479380; // _FogColor.a contains exposure

            // Lerp between source color to skybox color with fog amount.
            return half4(skyColor, blend);
        }

    ENDHLSL

    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            ZWrite Off
            ZTest Always
            Blend SrcAlpha OneMinusSrcAlpha
            HLSLPROGRAM
                #pragma vertex VertDefault
                #pragma fragment Frag
            ENDHLSL
        }

        Pass
        {
            ZWrite Off
            ZTest Always
            Blend SrcAlpha OneMinusSrcAlpha
            HLSLPROGRAM
                #pragma vertex VertDefault
                #pragma fragment FragExcludeSkybox
            ENDHLSL
        }

        Pass
        {
            ZWrite Off
            ZTest Always
            Blend SrcAlpha OneMinusSrcAlpha
            HLSLPROGRAM
                #pragma vertex VertFogFade
                #pragma fragment FragFadeToSkybox
            ENDHLSL
        }
    }
}
