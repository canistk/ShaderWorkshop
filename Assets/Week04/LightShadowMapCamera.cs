using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/// <summary>
/// https://www.youtube.com/watch?v=oPxY1eTrrOo
/// </summary>
[ExecuteAlways]
[RequireComponent(typeof(Light))]
public class LightShadowMapCamera : MonoBehaviour
{
    public Light m_Light;
    public Camera m_ShadowCam;
    public Shader m_Shader = null;
    public RenderTexture m_ShadowMap = null;

	private void Reset()
    {
        m_Light = GetComponent<Light>();
    }

    private void Update()
    {
		if (m_Shader == null)
			return;
		if (m_ShadowCam == null)
			CreateShadowMapCamera();

        Matrix4x4 shadowVP = m_ShadowCam.projectionMatrix * m_ShadowCam.worldToCameraMatrix;
		Shader.SetGlobalMatrix("_MyShadowVP", shadowVP);
		Shader.SetGlobalTexture("_MyShadowMap", m_ShadowMap);
		// Debug.Log(shadowVP);
		m_ShadowCam.ResetReplacementShader();
		m_ShadowCam.depthTextureMode = DepthTextureMode.Depth;
		m_ShadowCam.renderingPath = RenderingPath.Forward;
		m_ShadowCam.targetTexture = m_ShadowMap;
		m_ShadowCam.forceIntoRenderTexture = true;
		m_ShadowCam.orthographic = true;
		m_ShadowCam.SetReplacementShader(m_Shader, null);
		m_ShadowCam.Render();
		// m_ShadowCam.RenderWithShader(m_Shader, null);
	}

	private void CreateShadowMapCamera()
    {
		if (m_ShadowCam != null)
			return;
		m_ShadowCam = GetComponentInChildren<Camera>();
		if (m_ShadowCam != null)
			return;
		GameObject lightCamera = new GameObject("Shadow Map Camera");
		lightCamera.transform.SetParent(m_Light.transform, false);
		m_ShadowCam = lightCamera.AddComponent<Camera>();
		m_ShadowCam.hideFlags = HideFlags.DontSaveInEditor;
		m_ShadowCam.enabled = false;
	}
}
