using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Kit
{
    /// <summary>
    /// In order to add render piple line without access ForwardRender.asset
    /// </summary>
    [ExecuteInEditMode]
    public abstract class URPCustomRenderBase : MonoBehaviour
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingTransparents;
        public RenderTargetIdentifier cameraColorTarget;

        public virtual void OnEnable()
        {
            URPHelper.instance.Register(this);
        }
        public virtual void OnDisable()
        {
            URPHelper.instance.UnRegister(this);
        }

        public virtual void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor) { }

        public virtual void FrameCleanup(CommandBuffer cmd) { }

        public virtual void Execute(ScriptableRenderContext context, ref RenderingData renderingData) { }

        public virtual void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData) { }
        public virtual void OnCameraCleanup(CommandBuffer cmd) { }
        public virtual void OnFinishCameraStackRendering(CommandBuffer cmd) { }
    }

    [ExecuteInEditMode]
    public class URPRenderPass : ScriptableRenderPass
    {
        URPCustomRenderBase m_Volume;
        public URPRenderPass(URPCustomRenderBase vol) { m_Volume = vol; }

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            if (m_Volume)
                m_Volume.Configure(cmd, cameraTextureDescriptor);
        }

        public override void FrameCleanup(CommandBuffer cmd)
        {
            if (m_Volume)
                m_Volume.FrameCleanup(cmd);
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (m_Volume)
                m_Volume.Execute(context, ref renderingData);
        }

        public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
        {
            if (m_Volume)
                m_Volume.OnCameraSetup(cmd, ref renderingData);
        }

        public override void OnCameraCleanup(CommandBuffer cmd)
        {
            if (m_Volume)
                m_Volume.OnCameraCleanup(cmd);
        }

        public override void OnFinishCameraStackRendering(CommandBuffer cmd)
        {
            if (m_Volume)
                m_Volume.OnFinishCameraStackRendering(cmd);
        }
    }
}