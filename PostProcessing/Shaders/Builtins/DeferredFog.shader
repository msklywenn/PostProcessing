Shader "Hidden/PostProcessing/DeferredFog"
{
    HLSLINCLUDE

        #pragma multi_compile __ FOG_LINEAR FOG_EXP FOG_EXP2
        #include "../StdLib.hlsl"
        #include "Fog.hlsl"

        TEXTURE2D_SAMPLER2D(_CameraDepthTexture, sampler_CameraDepthTexture);

        #define SKYBOX_THRESHOLD_VALUE 0.9999

        #define UNITY_MATRIX_P glstate_matrix_projection
        CBUFFER_START(UnityPerFrame)
            float4x4 glstate_matrix_projection;
        CBUFFER_END

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

            float near = _ProjectionParams.y;
            float far = _ProjectionParams.z;

            AttributesDefault defAttribs;
            defAttribs.vertex = v.vertex;
            o.deffault = VertDefault(defAttribs);

            // extra FOG_START to compensate for hack in fragment shader...
            // multiplication by 0.999 fixes precision issue on switch
#if FOG_LINEAR
            float fogStart = -clamp(FOG_START * 2, near, far * 0.999);
#else
            float fogStart = -clamp(FOG_START, near, far * 0.999);
#endif
            float4 p = mul(UNITY_MATRIX_P, float4(0, 0, fogStart, 1));
            o.deffault.vertex.z = p.z / p.w;

            float tanHalfFovX = 1 / UNITY_MATRIX_P[0][0];
            float tanHalfFovY = 1 / UNITY_MATRIX_P[1][1];
            float3 right = unity_WorldToCamera[0].xyz * near * tanHalfFovX;
            float3 top = unity_WorldToCamera[1].xyz * near * tanHalfFovY;
            float2 corner = v.vertex.xy;
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
            //depth = Linear01Depth(depth);
            depth = 1.0 / (_ZBufferParams.x * depth + _ZBufferParams.y);

            float dist = ComputeFogDistance(depth) - FOG_START; // -FOG_START hack! to push away exponential fog
            half fog = 1.0 - ComputeFog(dist);
            float skybox = depth > SKYBOX_THRESHOLD_VALUE;

            float blend = saturate(fog + skybox);

            // Look up the skybox color.
            half3 skyColor = texCUBE(_SkyCubemap, i.ray);
            skyColor *= _FogColor.rgb * _FogColor.a * 4.59479380; // _FogColor.a contains exposure

            // Lerp between source color to skybox color with fog amount.
            return half4(skyColor, blend);
        }

    ENDHLSL

    SubShader
    {
        Cull Off
        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            ZTest Always
            HLSLPROGRAM
                #pragma vertex VertDefault
                #pragma fragment Frag
            ENDHLSL
        }

        Pass
        {
            ZTest Always
            HLSLPROGRAM
                #pragma vertex VertDefault
                #pragma fragment FragExcludeSkybox
            ENDHLSL
        }

        Pass
        {
            ZTest Less
            HLSLPROGRAM
                #pragma vertex VertFogFade
                #pragma fragment FragFadeToSkybox
            ENDHLSL
        }
    }
}
