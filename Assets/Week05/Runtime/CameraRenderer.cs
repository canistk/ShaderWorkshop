using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Experimental.Rendering;

public partial class CameraRenderer
{
    ScriptableRenderContext context;
    Camera camera;
    const string bufferName = "Render Camera";
    CullingResults cullingResults;
    static ShaderTagId 
        unlitShaderTagId = new ShaderTagId("CustomUnlit"),
        litShaderTagId = new ShaderTagId("CustomLit"),
        gBufferShaderTagId = new ShaderTagId("GBuffer");

    Lighting lighting = new Lighting();
    CommandBuffer cmd = new CommandBuffer {};
    public struct GBuffer
    {
        public static readonly int positionWSHash = Shader.PropertyToID("Rt_PositionWS");
        public static readonly int normalWSHash = Shader.PropertyToID("Rt_NormalWS");
        public static readonly int albedoHash = Shader.PropertyToID("Rt_Albedo");
        public static readonly int depthHash = Shader.PropertyToID("Rt_Depth");
        public static readonly RenderTargetIdentifier rtPositionWS = new RenderTargetIdentifier(positionWSHash, 0, CubemapFace.Unknown, 0);
        public static readonly RenderTargetIdentifier rtNormalWS = new RenderTargetIdentifier(normalWSHash, 0, CubemapFace.Unknown, 0);
        public static readonly RenderTargetIdentifier rtAlbedo = new RenderTargetIdentifier(albedoHash, 0, CubemapFace.Unknown, 0);
        public static readonly RenderTargetIdentifier rtDepth = new RenderTargetIdentifier(depthHash, 0, CubemapFace.Unknown, 0);
        public static readonly RenderTargetIdentifier[] renderTargetIdentifiers =
        {
            rtPositionWS,
            rtNormalWS,
            rtAlbedo,
        };
    }
    public void Render(ScriptableRenderContext context, Camera camera, bool useDynamicBatching, bool useGPUInstancing)
    {
        this.context = context;
        this.camera = camera;
        context.SetupCameraProperties(camera);
        if (Cull(out cullingResults))
        {
            PrepareGBuffer();

            PrepareBuffer();
            cmd.BeginSample(SampleName);
            ApplyCameraCleanFlag(camera);
            PrepareForSceneWindow();
            context.ExecuteCommandBuffer(cmd);
            cmd.Clear();

            lighting.Setup(context, cullingResults);
            DrawVisibleGeometry(useDynamicBatching, useGPUInstancing);
            DrawUnsupportedShaders();
            cmd.EndSample(SampleName);
        }
        DrawGizmos();


        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();
        context.Submit();
    }

    private void ApplyCameraCleanFlag(Camera camera)
    {
        CameraClearFlags flags = camera.clearFlags;
        cmd.ClearRenderTarget(
            flags <= CameraClearFlags.Depth,
            flags == CameraClearFlags.Color,
            flags == CameraClearFlags.Color ?
                camera.backgroundColor.linear : Color.clear);
    }

    bool Cull(out CullingResults rst)
    {
        if (camera.TryGetCullingParameters(out ScriptableCullingParameters p))
        {
            rst = context.Cull(ref p);
            return true;
        }
        rst = default;
        return false;
    }
    partial void PrepareBuffer();
    partial void PrepareForSceneWindow();
    void PrepareGBuffer()
    {
        const string _cmdName = "Render_GBuffer";
        cmd.name = _cmdName;
        cmd.BeginSample(_cmdName);
        RenderTextureDescriptor descriptor = new RenderTextureDescriptor(camera.pixelWidth, camera.pixelHeight, RenderTextureFormat.Default, 24, 0);
        cmd.GetTemporaryRT(GBuffer.positionWSHash, descriptor, FilterMode.Point);
        cmd.GetTemporaryRT(GBuffer.normalWSHash, descriptor, FilterMode.Point);
        cmd.GetTemporaryRT(GBuffer.albedoHash, descriptor, FilterMode.Point);
        cmd.GetTemporaryRT(GBuffer.depthHash, descriptor, FilterMode.Point);

        cmd.SetRenderTarget(GBuffer.renderTargetIdentifiers, GBuffer.depthHash);
        cmd.ClearRenderTarget(true, true, Color.clear);

        var sortingSettings = new SortingSettings(camera)
        {
            criteria = SortingCriteria.CommonOpaque
        };
        var drawingSettings = new DrawingSettings(gBufferShaderTagId, sortingSettings)
        {
            enableDynamicBatching = true,
            enableInstancing = true,
        };
        var filteringSettings = new FilteringSettings(RenderQueueRange.opaque);
        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();
        context.DrawRenderers(cullingResults, ref drawingSettings, ref filteringSettings);

        cmd.SetGlobalTexture(GBuffer.positionWSHash, GBuffer.rtPositionWS);
        cmd.SetGlobalTexture(GBuffer.normalWSHash, GBuffer.rtNormalWS);
        cmd.SetGlobalTexture(GBuffer.albedoHash, GBuffer.rtAlbedo);
        cmd.SetGlobalTexture(GBuffer.depthHash, GBuffer.rtDepth);

        cmd.ReleaseTemporaryRT(GBuffer.positionWSHash);
        cmd.ReleaseTemporaryRT(GBuffer.normalWSHash);
        cmd.ReleaseTemporaryRT(GBuffer.albedoHash);
        cmd.ReleaseTemporaryRT(GBuffer.depthHash);

        cmd.EndSample(_cmdName);
    }
    void DrawVisibleGeometry(bool useDynamicBatching, bool useGPUInstancing)
    {
        var sortingSettings = new SortingSettings(camera) { criteria = SortingCriteria.CommonOpaque };
        var drawingSettings = new DrawingSettings(unlitShaderTagId, sortingSettings)
        {
            enableDynamicBatching = useDynamicBatching,
            enableInstancing = useGPUInstancing,
        };
        drawingSettings.SetShaderPassName(1, litShaderTagId);
        var filteringSettings = new FilteringSettings(RenderQueueRange.opaque);
        context.DrawRenderers(cullingResults, ref drawingSettings, ref filteringSettings);


        context.DrawSkybox(camera);

        sortingSettings.criteria = SortingCriteria.CommonTransparent;
        drawingSettings.sortingSettings = sortingSettings;
        filteringSettings.renderQueueRange = RenderQueueRange.transparent;
        context.DrawRenderers(cullingResults, ref drawingSettings, ref filteringSettings);
    }
    partial void DrawUnsupportedShaders();
    partial void DrawGizmos();

}
