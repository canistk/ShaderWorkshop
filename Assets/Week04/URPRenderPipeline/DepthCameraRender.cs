using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Kit
{
    public class DepthCameraRender : URPCustomRenderBase
    {
		public Camera ProjectorCamera;
        public Shader copyDepthShader;
        public RenderTexture projDepthTenderTarget;
        private Material copyDepthMaterial;
        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            base.Configure(cmd, cameraTextureDescriptor);
            
        }
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (renderingData.cameraData.camera != ProjectorCamera)
                return;
            // below session only for projector camera.
        }
    }
}