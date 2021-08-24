using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace Kit
{
    /// <summary>
    /// Require to register <see cref="DynamicRendererFeature"/> once,
    /// into "URP/Setting/ForwardRender.asset" by doing that,
    /// we can use <see cref="URPHelper"/> to dynamic apply render pass by code.
    /// instead of play around those complicate setting.
    /// on pipe line & scriptableobject mess.
    /// </summary>
    public class DynamicRendererFeature : ScriptableRendererFeature
    {
        public override void Create()
        {
            // Debug.Log($"{nameof(DynamicRendererFeature)}.Create");
        }
        public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            // Debug.Log($"{nameof(DynamicRendererFeature)}.RendererFeature.AddRenderPasses");
            if (URPHelper.instance == null)
                return;
            URPHelper.instance.AddRenderPasses(renderer, ref renderingData);
        }
    }

    /// <summary>
    /// Require to add <see cref="DynamicRendererFeature"/> on ForwardRender.asset.
    /// </summary>
    public class URPHelper
    {
        private static URPHelper s_instance;
        public static URPHelper instance
        {
            get
            {
                if (s_instance == null)
                    s_instance = new URPHelper();
                return s_instance;
            }
        }
        Dictionary<URPCustomRenderBase, ScriptableRenderPass> m_volumes = new Dictionary<URPCustomRenderBase, ScriptableRenderPass>();

        public void Register(URPCustomRenderBase customRenderBase)
        {
            m_volumes.Add(customRenderBase, new URPRenderPass(customRenderBase));
        }

        public void UnRegister(URPCustomRenderBase customRenderBase)
        {
            if (m_volumes.ContainsKey(customRenderBase))
                m_volumes.Remove(customRenderBase);
        }

        internal void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
        {
            foreach (var kvp in m_volumes)
            {
                if (kvp.Key == null || kvp.Value == null) continue;
                kvp.Key.cameraColorTarget = renderer.cameraColorTarget;
                kvp.Value.renderPassEvent = kvp.Key.renderPassEvent;
                renderer.EnqueuePass(kvp.Value);
            }

            if (OnAddRenderPasses != null)
                OnAddRenderPasses.Invoke(renderer, ref renderingData);
        }

        public delegate void OnAddRenderPassesDelegate(ScriptableRenderer renderer, ref RenderingData renderingData);
        public event OnAddRenderPassesDelegate OnAddRenderPasses;
    }

}