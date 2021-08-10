using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class TrailUpdateHelper : MonoBehaviour
{
    [SerializeField] Renderer m_Renderer = null;
    Material m_Material;
    int hash = -1;
    private void Awake()
    {
        if (hash == -1)
            hash = Shader.PropertyToID("_SysTime");
        m_Material = new Material(m_Renderer.sharedMaterial);
        m_Renderer.sharedMaterial = m_Material;
    }

    void Update()
    {
        if (m_Material == null)
            return;
        // if (m_Renderer.sharedMaterial.HasProperty(hash))
        m_Material.SetFloat(hash, Time.timeSinceLevelLoad);
    }
}
