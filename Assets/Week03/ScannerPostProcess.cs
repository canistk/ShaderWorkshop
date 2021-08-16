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
    }
    private void Update()
	{
		if (material && m_ScannerToken != null)
		{
			material.SetVector("_Origin", m_ScannerToken.position);
		}
	}
}