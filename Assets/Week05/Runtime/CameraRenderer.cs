using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

public partial class CameraRenderer
{
    ScriptableRenderContext context;
    Camera camera;
    const string bufferName = "Render Camera";
    CullingResults cullingResults;
    static ShaderTagId 
        unlitShaderTagId = new ShaderTagId("SRPDefaultUnlit"),
        litShaderTagId = new ShaderTagId("CustomLit"),
        gBufferShaderTagId = new ShaderTagId("GBuffer");

    Lighting lighting = new Lighting();
    CommandBuffer buffer = new CommandBuffer {};
    GBuffer gBuffer;
    public void AssignGBuffer(GBuffer gBuffer)
    {
        this.gBuffer = gBuffer;
    }

    public void Render(ScriptableRenderContext context, Camera camera, bool useDynamicBatching, bool useGPUInstancing)
    {
        this.context = context;
        this.camera = camera;


        PrepareBuffer();
        PrepareForSceneWindow();
        if (!Cull())
        {
            return;
        }

        FetchGBuffer();

        Setup();
        lighting.Setup(context, cullingResults);
        DrawVisibleGeometry(useDynamicBatching, useGPUInstancing);
        DrawUnsupportedShaders();
        DrawGizmos();
        Submit();
    }

    bool Cull()
    {
        if (camera.TryGetCullingParameters(out ScriptableCullingParameters p))
        {
            cullingResults = context.Cull(ref p);
            return true;
        }
        return false;
    }
    partial void PrepareBuffer();
    partial void PrepareForSceneWindow();
    void Setup()
    {
        context.SetupCameraProperties(camera);
        CameraClearFlags flags = camera.clearFlags;
        buffer.ClearRenderTarget(
            flags <= CameraClearFlags.Depth,
            flags == CameraClearFlags.Color,
            flags == CameraClearFlags.Color ?
                camera.backgroundColor.linear : Color.clear);
        buffer.BeginSample(SampleName);
        ExecuteBuffer();
    }
    void ExecuteBuffer()
    {
        context.ExecuteCommandBuffer(buffer);
        buffer.Clear();
    }
    void FetchGBuffer()
    {
        context.SetupCameraProperties(camera);
        buffer.ClearRenderTarget(true, true, Color.blue);
        ExecuteBuffer();

        buffer.SetRenderTarget(new RenderTargetIdentifier[2]
        {
            gBuffer.positionId,
            gBuffer.normalsId
        },
        gBuffer.depthId);
        context.ExecuteCommandBuffer(buffer);
        context.Submit();
        buffer.Clear();

        //var sortingSettings = new SortingSettings(camera)
        //{
        //    criteria = SortingCriteria.CommonOpaque // Problem ?!
        //};
        //var drawingSettings = new DrawingSettings(gBufferShaderTagId, sortingSettings)
        //{
        //    enableDynamicBatching = true,
        //    enableInstancing = true,
        //};
        //var filteringSettings = new FilteringSettings(RenderQueueRange.all);
        //context.DrawRenderers(cullingResults, ref drawingSettings, ref filteringSettings);
        //ExecuteBuffer();
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
    void Submit()
    {
        buffer.EndSample(SampleName);
        ExecuteBuffer();
        context.Submit();
    }
}
