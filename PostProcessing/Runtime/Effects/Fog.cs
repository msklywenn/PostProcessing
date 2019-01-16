using System;
using System.Collections.Generic;

namespace UnityEngine.Rendering.PostProcessing
{
    /// <summary>
    /// This class holds settings for the Fog effect with the deferred rendering path.
    /// </summary>
    [Serializable]
    public sealed class Fog
    {
        public enum Mode
        {
            IncludeSkybox,
            ExcludeSkybox,
            FadeToSkybox,
        }

        /// <summary>
        /// If <c>true</c>, enables the internal deferred fog pass. Actual fog settings should be
        /// set in the Lighting panel.
        /// </summary>
        [Tooltip("Enables the internal deferred fog pass. Actual fog settings should be set in the Lighting panel.")]
        public bool enabled = true;

        /// <summary>
        /// Should the fog affect the skybox?
        /// </summary>
        [Tooltip("Mark true for the fog to ignore the skybox")]
        public Mode skyboxMode = Mode.FadeToSkybox;

        internal DepthTextureMode GetCameraFlags()
        {
            return DepthTextureMode.Depth;
        }

        internal bool IsEnabledAndSupported(PostProcessRenderContext context)
        {
            return enabled
                && RenderSettings.fog
                && !RuntimeUtilities.scriptableRenderPipelineActive
                && context.resources.shaders.deferredFog
                && context.resources.shaders.deferredFog.isSupported
                && context.camera.actualRenderingPath == RenderingPath.DeferredShading;  // In forward fog is already done at shader level
        }

        internal void Render(PostProcessRenderContext context)
        {

            var sheet = context.propertySheets.Get(context.resources.shaders.deferredFog);
            sheet.ClearKeywords();

            switch (RenderSettings.fogMode)
            {
                case FogMode.Linear:
                    sheet.EnableKeyword("FOG_LINEAR");
                    break;
                case FogMode.Exponential:
                    sheet.EnableKeyword("FOG_EXP");
                    break;
                case FogMode.ExponentialSquared:
                    sheet.EnableKeyword("FOG_EXP2");
                    break;
            }

            Material skybox = RenderSettings.skybox;
            Texture cubemap = null;
            if (skyboxMode == Mode.FadeToSkybox && skybox != null && (cubemap = skybox.GetTexture(ShaderIDs.Texture)) != null)
            {
                var fogColor = skybox.GetColor(ShaderIDs.Tint).linear;
                float exposure = skybox.GetFloat(ShaderIDs.Exposure);
                float rotation = Mathf.Deg2Rad * skybox.GetFloat(ShaderIDs.Rotation);
                sheet.properties.SetVector(ShaderIDs.FogColor, new Vector4(fogColor.r, fogColor.g, fogColor.b, exposure));
                sheet.properties.SetVector(ShaderIDs.FogParams, new Vector4(RenderSettings.fogDensity,
                    RenderSettings.fogStartDistance, RenderSettings.fogEndDistance, -rotation));
                sheet.properties.SetTexture(ShaderIDs.SkyCubemap, cubemap);

                var cmd = context.command;
                cmd.BlitFullscreenTriangle(context.source, context.destination, sheet, (int)skyboxMode);
            }
            else
            {
                var fogColor = RuntimeUtilities.isLinearColorSpace ? RenderSettings.fogColor.linear : RenderSettings.fogColor;
                sheet.properties.SetVector(ShaderIDs.FogColor, fogColor);
                sheet.properties.SetVector(ShaderIDs.FogParams, new Vector3(RenderSettings.fogDensity, RenderSettings.fogStartDistance, RenderSettings.fogEndDistance));

                var cmd = context.command;
                cmd.BlitFullscreenTriangle(context.source, context.destination, sheet, (int)skyboxMode);
            }
        }
    }
}
