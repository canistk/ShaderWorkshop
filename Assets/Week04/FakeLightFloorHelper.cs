using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class FakeLightFloorHelper : MonoBehaviour
{
    public Renderer m_Renderer = null;
    private MaterialPropertyBlock m_Block = null;

    public Light m_LightSrc = null;
    public MeshRenderer m_Glass = null;

    private void Update()
    {
        if (m_Renderer == null)
            return;
        if (m_Block == null)
            m_Block = new MaterialPropertyBlock();

        // m_Block.SetVector

        m_Renderer.SetPropertyBlock(m_Block);
    }
}
