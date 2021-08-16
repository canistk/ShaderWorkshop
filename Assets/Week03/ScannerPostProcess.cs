using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;


[ExecuteInEditMode]
public class ScannerPostProcess : MyPostProcessSimple
{
	[SerializeField] Camera m_Camera = null;
	[SerializeField] Transform m_ScannerToken = null;

    private void Awake()
    {
		if (m_Camera == null)
			m_Camera = Camera.main;
		m_Camera.depthTextureMode = DepthTextureMode.Depth;
	}
    private void Update()
	{
		if (material && m_ScannerToken != null)
		{
			material.SetVector("_Origin", m_ScannerToken.position);
			if (m_Camera)
            {
				Matrix4x4 m = GL.GetGPUProjectionMatrix(m_Camera.projectionMatrix, false);
				m[2, 3] = m[3, 2] = 0.0f; m[3, 3] = 1.0f;
				Matrix4x4 ProjectionToWorld = Matrix4x4.Inverse(m * m_Camera.worldToCameraMatrix)
					* Matrix4x4.TRS(new Vector3(0, 0, -m[2, 2]), Quaternion.identity, Vector3.one);
				// Matrix4x4.Translate(new Vector3(0, 0, -m[2, 2]));
				material.SetMatrix("_unity_ProjectionToWorld", ProjectionToWorld);
            }
		}
	}
}