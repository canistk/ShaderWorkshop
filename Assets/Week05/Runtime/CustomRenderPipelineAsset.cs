using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;

[CreateAssetMenu(menuName = "Rendering/Custom Render Pipeline")]
public class CustomRenderPipelineAsset : RenderPipelineAsset
{
    [SerializeField]
    bool useDynamicBatching = true, useGPUInstancing = true, useSRPBatcher = true;

    [SerializeField] RenderTexture rtPosition, rtNormals, rtDepth, rtAlbedo, rtSpecular;
    [SerializeField] Shader gBufferShader;

    protected override RenderPipeline CreatePipeline()
    {
        GBuffer gBuffer = new GBuffer(rtPosition, rtNormals, rtDepth, rtAlbedo, rtSpecular, new Material(gBufferShader));
        return new CustomRenderPipeline(useDynamicBatching, useGPUInstancing, useSRPBatcher, gBuffer);
    }
}

public struct GBuffer
{
    public RenderTexture position, normals, depth, albedo, specular;
    public RenderTargetIdentifier positionId, normalsId, albedoId, specularId, depthId;
    public Material gBufferMaterial;
    public GBuffer(RenderTexture position,
        RenderTexture normals,
        RenderTexture depth,
        RenderTexture albedo,
        RenderTexture specular, Material gBufferMaterial)
    {
        this.position = position;
        this.normals = normals;
        this.depth = depth;
        this.albedo = albedo;
        this.specular = specular;
        this.gBufferMaterial = gBufferMaterial;
        positionId = new RenderTargetIdentifier(position, 0, CubemapFace.Unknown, 0);
        normalsId = new RenderTargetIdentifier(normals, 0, CubemapFace.Unknown, 0);
        depthId = new RenderTargetIdentifier(depth, 0, CubemapFace.Unknown, 0);
        albedoId = new RenderTargetIdentifier(albedo, 0, CubemapFace.Unknown, 0);
        specularId = new RenderTargetIdentifier(specular, 0, CubemapFace.Unknown, 0);
    }
}