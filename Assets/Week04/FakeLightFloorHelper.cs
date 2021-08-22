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

        if (m_LightSrc)
        {
            Matrix4x4 localToWorldMatrix = m_LightSrc.transform.localToWorldMatrix;
            // if (m_LightSrc.type == LightType.Spot) { }
            m_Block.SetMatrix("_LightMatrixLocalToWorld", localToWorldMatrix);
            // m_Block.SetMatrix("_LightMatrixWorldToLocal", m_LightSrc.transform.worldToLocalMatrix);
            m_Block.SetColor("_LightColor", m_LightSrc.color);
            Vector4 lightSetting = new Vector4
            {
                x = m_LightSrc.range,
                y = m_LightSrc.intensity,
                z = Mathf.Deg2Rad * Mathf.Min(m_LightSrc.innerSpotAngle * 0.5f, 88.0f),
                w = Mathf.Deg2Rad * Mathf.Min(m_LightSrc.spotAngle * 0.5f, 90.0f),
            };
            m_Block.SetVector("_LightSetting", lightSetting);
        }

        if (m_Glass && m_Glass.transform != null)
        {
            Transform glass = m_Glass.transform;
            m_Block.SetMatrix("_GlassMatrixLocalToWorld", glass.localToWorldMatrix);
            m_Block.SetMatrix("_GlassMatrixWorldToLocal", glass.worldToLocalMatrix);
            var texture = m_Glass.sharedMaterial.mainTexture;
            m_Block.SetTexture("_GlassTex", texture);
            m_Block.SetInt("_HadGlass", 1);
            //Vector2 offset = m_Glass.material.mainTextureOffset;
            //Vector2 scale = m_Glass.material.mainTextureScale;
            //Vector2 offset = m_Glass.material.GetTextureOffset("_BaseTex");
            //Vector2 scale = m_Glass.material.GetTextureScale("_BaseTex");
            //Vector4 glassTex_ST = new Vector4(offset.x, offset.y, scale.x, scale.y);
        }
        else
        {
            m_Block.SetInt("_HadGlass", 0);
        }

        m_Renderer.SetPropertyBlock(m_Block);
    }

    private void OnDrawGizmos()
    {
        Color old = Gizmos.color;
        Matrix4x4 m = m_LightSrc.transform.localToWorldMatrix;
        Vector3 point = m.MultiplyPoint(Vector3.zero);
        Vector3 forward = m.MultiplyVector(Vector3.forward);
        Gizmos.color = Color.red;
        Gizmos.DrawSphere(point, 0.2f);
        Gizmos.DrawRay(point, forward);
        Gizmos.color = old;
    }
}
