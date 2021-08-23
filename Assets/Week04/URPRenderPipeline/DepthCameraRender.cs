using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Kit
{
    public class DepthCameraRender : URPCustomRenderBase
    {
		public Camera m_Camera;
        RenderTargetIdentifier colorBuffer, temporaryBuffer;
        int temporaryBufferID = Shader.PropertyToID("_TemporaryBuffer");

        // TODO:
        // https://gist.github.com/alexanderameye/bb4ec2798a2d101ad505ce4f7a0f58f4
        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            RenderTextureDescriptor descriptor = renderingData.cameraData.cameraTargetDescriptor;
            // Downsample the original camera target descriptor. 
            // You would do this for performance reasons or less commonly, for aesthetics.
            //descriptor.width /= passSettings.downsample;
            //descriptor.height /= passSettings.downsample;

            // Set the number of depth bits we need for our temporary render texture.
            descriptor.depthBufferBits = 0;
            // Enable these if your pass requires access to the CameraDepthTexture or the CameraNormalsTexture.
            //ConfigureInput(ScriptableRenderPassInput.Depth);
            //ConfigureInput(ScriptableRenderPassInput.Normal);

            // Grab the color buffer from the renderer camera color target.
            colorBuffer = renderingData.cameraData.renderer.cameraColorTarget;
            // Create a temporary render texture using the descriptor from above.
            cmd.GetTemporaryRT(temporaryBufferID, descriptor, FilterMode.Bilinear);
            temporaryBuffer = new RenderTargetIdentifier(temporaryBufferID);
        }
        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            if (cmd == null) throw new System.ArgumentNullException("cmd");

            // Since we created a temporary render texture in OnCameraSetup, we need to release the memory here to avoid a leak.
            cmd.ReleaseTemporaryRT(temporaryBufferID);
        }
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            // Grab a command buffer. We put the actual execution of the pass inside of a profiling scope.
            CommandBuffer cmd = CommandBufferPool.Get();
            //using (new ProfilingScope(cmd, new ProfilingSampler(ProfilerTag)))
            //{
            //    // Blit from the color buffer to a temporary buffer and back. This is needed for a two-pass shader.
            //    Graphics.Blit(cmd, colorBuffer, temporaryBuffer, material, 0); // shader pass 0
            //    Graphics.Blit(cmd, temporaryBuffer, colorBuffer, material, 1); // shader pass 1
            //}

            // Execute the command buffer and release it.
            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }
    }
}