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

        Mesh quad;
        List<Vector3> texcoord1 = new List<Vector3>(new Vector3[4]);

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
            if (quad == null)
            {
                quad = new Mesh()
                {
                    vertices = new Vector3[]
                    {
                        new Vector3(-1f, -1f, 0f),
                        new Vector3( 1f, -1f, 0f),
                        new Vector3( 1f,  1f, 0f),
                        new Vector3(-1f,  1f, 0f)
                    },
                    uv = new Vector2[]
                    {
                        new Vector2(0, 0),
                        new Vector2(1, 0),
                        new Vector2(1, 1),
                        new Vector2(0, 1),
                    },
                };
                quad.SetIndices(new int[] { 0, 1, 2, 3 }, MeshTopology.Quads, 0);
                quad.MarkDynamic();
            }

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

                // Calculate vectors towards frustum corners.
                var cam = context.camera;
                var camtr = cam.transform;
                var camNear = cam.nearClipPlane;
                var camFar = cam.farClipPlane;

                var tanHalfFov = Mathf.Tan(cam.fieldOfView * Mathf.Deg2Rad / 2);
                var toRight = camtr.right * camNear * tanHalfFov * cam.aspect;
                var toTop = camtr.up * camNear * tanHalfFov;

                var origin = camtr.forward * camNear;
                var v_tl = origin - toRight + toTop;
                var v_tr = origin + toRight + toTop;
                var v_br = origin + toRight - toTop;
                var v_bl = origin - toRight - toTop;

                var v_s = v_tl.magnitude * camFar / camNear;

                if (SystemInfo.graphicsUVStartsAtTop)
                {
                    texcoord1[0] = v_tl.normalized * v_s;
                    texcoord1[1] = v_tr.normalized * v_s;
                    texcoord1[2] = v_br.normalized * v_s;
                    texcoord1[3] = v_bl.normalized * v_s;
                }
                else
                {
                    texcoord1[0] = v_bl.normalized * v_s;
                    texcoord1[1] = v_br.normalized * v_s;
                    texcoord1[2] = v_tr.normalized * v_s;
                    texcoord1[3] = v_tl.normalized * v_s;
                }

                quad.SetUVs(1, texcoord1);

                var cmd = context.command;
                cmd.SetGlobalTexture(ShaderIDs.MainTex, context.source);
                cmd.SetRenderTargetWithLoadStoreAction(context.destination, RenderBufferLoadAction.DontCare, RenderBufferStoreAction.Store);
                cmd.DrawMesh(quad, Matrix4x4.identity, sheet.material, 0, (int)skyboxMode, sheet.properties);
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
