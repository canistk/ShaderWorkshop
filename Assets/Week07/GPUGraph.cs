using System.Collections;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using UnityEngine;
/// <summary>
/// https://github.com/SimpleTalkCpp/workshop-2021-07-unity-shader/tree/main/Assets/Week007
/// </summary>
// [ExecuteInEditMode]
public class GPUGraph : MonoBehaviour
{
    [SerializeField] Mesh m_Mesh;
    [SerializeField] Material m_Material;
    [SerializeField] ComputeShader m_Shader;
    [SerializeField] int m_ParticleAmount = 1000;
    [SerializeField] Vector3 m_ParticleScale = Vector3.one;
    [SerializeField] Vector2 m_LifeTimeRange = new Vector2(3f, 5f);

    [Header("Draw Bound")]
    [SerializeField] Vector3 m_Offset = Vector3.zero;
    [SerializeField] Vector3 m_Size = Vector3.one;


    [SerializeField] bool m_GizmosDebug = false;

    Bounds GetDrawBounds()
    {
        return new Bounds
        {
            center = transform.TransformPoint(m_Offset),
            size = m_Size
        };
    }
    RenderTexture m_Tex;
    int m_KernelIndex;
    
    #region System
    private void OnEnable()
    {
        StartParticle();
    }

    private void OnDisable()
    {
        FreeMemory();
    }

    private void Update()
    {
        // if (Application.isPlaying)
        Execute();
    }

    private void Execute()
    {
        m_Shader.SetFloat(s_DeltaTime, Time.deltaTime);
        
        const int numThread = 512; // must sync with compute shader numthreads setting.
        int particleCount = m_ParticleAmount;
        int threadGroup = (particleCount + numThread - 1) / numThread;
        if (threadGroup <= 0)
            return;
        m_Shader.Dispatch(m_KernelIndex, threadGroup, 1, 1);

        if (m_Material)
            Graphics.DrawProcedural(m_Material, GetDrawBounds(), MeshTopology.Triangles, m_MeshTriangles.count, m_ParticleAmount);
    }

    private void OnDrawGizmos()
    {
        if (!m_GizmosDebug)
            return;
        if (m_PositionBuffer != null && m_PositionBuffer.IsValid())
        {
            m_PositionBuffer.GetData(m_PositionData);
            if (m_PositionData == null)
                return;

            Color old = Gizmos.color;
            foreach (var p in m_PositionData)
            {
                Gizmos.DrawSphere(p, 0.05f);
            }
            Gizmos.color = old;
        }
    }
    #endregion System

    #region Particle data structure and stride size
    const string s_FunctionKernal = "FunctionKernel";
    ComputeBuffer m_MeshTriangles, m_MeshVertices;
    ComputeBuffer m_PositionBuffer, m_ScaleBuffer, m_VelocityBuffer, m_ColorBuffer, m_LifetimeBuffer;
    static readonly int s_TrianglesBufferName = Shader.PropertyToID("myTriangles");
    static readonly int s_VerticesBufferName = Shader.PropertyToID("myVertices");
    static readonly int s_PositionBufferName = Shader.PropertyToID("myPositions");
    static readonly int s_DeltaTime = Shader.PropertyToID("deltaTime");

    private Vector3[] m_PositionData; // stay global for debug purpose.

    string GetReadableSize(double len)
    {
        string[] sizes = { "B", "KB", "MB", "GB", "TB" };
        int order = 0;
        while (len >= 1024 && order < sizes.Length - 1)
        {
            order++;
            len = len / 1024;
        }
        return $"{len} {sizes[order]}";
    }
    #endregion Particle data structure and stride size

    private void StartParticle()
    {
        if (!(m_Shader && m_Material && m_Mesh))
            return;

        // pass mesh into material -> GPU shader.
        if (m_Mesh)
        {
            int[] triangles = m_Mesh.triangles;
            m_MeshTriangles = new ComputeBuffer(triangles.Length, sizeof(float) * 3);
            m_MeshTriangles.SetData(triangles);
            m_Material.SetBuffer(s_TrianglesBufferName, m_MeshTriangles);

            Vector3[] vertex = m_Mesh.vertices;
            m_MeshVertices = new ComputeBuffer(vertex.Length, sizeof(float) * 3);
            m_MeshVertices.SetData(vertex);
            m_Material.SetBuffer(s_VerticesBufferName, m_MeshVertices);
        }

        m_KernelIndex = m_Shader.FindKernel(s_FunctionKernal);
        if (m_KernelIndex < 0)
        {
            Debug.LogError($"Fail to init kernel");
            return;
        }
        m_Shader.GetKernelThreadGroupSizes(m_KernelIndex, out var _x, out var _y, out var _z);
        Debug.Log($"Kernel {m_KernelIndex}, ThreadGroupSize : X {_x}, Y {_y}, Z {_z}");
        int totalStrideSize = 0, stride;
        int amount = m_ParticleAmount;

        m_PositionData = new Vector3[amount];
        Vector3[] scaleData = new Vector3[amount];
        Vector3[] velocityData = new Vector3[amount];
        Color[] colorData = new Color[amount];
        float[] lifeTimeData = new float[amount];

        for (int i = 0; i < amount; i++)
        {
            m_PositionData[i]   = Random.insideUnitSphere;
            scaleData[i]        = m_ParticleScale;
            velocityData[i]     = Random.insideUnitSphere;
            colorData[i]        = Random.ColorHSV();
            lifeTimeData[i]     = Random.Range(m_LifeTimeRange.x, m_LifeTimeRange.y);
        }

        totalStrideSize += stride = Marshal.SizeOf(typeof(Vector3));
        m_PositionBuffer = new ComputeBuffer(amount, stride);
        m_PositionBuffer.SetData(m_PositionData);

        totalStrideSize += stride = Marshal.SizeOf(typeof(Vector3));
        m_ScaleBuffer = new ComputeBuffer(amount, stride);
        m_ScaleBuffer.SetData(scaleData);

        totalStrideSize += stride = Marshal.SizeOf(typeof(Vector3));
        m_VelocityBuffer = new ComputeBuffer(amount, stride);
        m_VelocityBuffer.SetData(velocityData);

        totalStrideSize += stride = Marshal.SizeOf(typeof(Color));
        m_ColorBuffer = new ComputeBuffer(amount, stride);
        m_ColorBuffer.SetData(colorData);

        totalStrideSize += stride = Marshal.SizeOf(typeof(float));
        m_LifetimeBuffer = new ComputeBuffer(amount, stride);
        m_LifetimeBuffer.SetData(lifeTimeData);

        m_Shader.SetBuffer(m_KernelIndex, s_PositionBufferName, m_PositionBuffer);
        m_Shader.SetBuffer(m_KernelIndex, "myScale", m_ScaleBuffer);
        m_Shader.SetBuffer(m_KernelIndex, "myVelocity", m_VelocityBuffer);
        m_Shader.SetBuffer(m_KernelIndex, "myColor", m_ColorBuffer);
        m_Shader.SetBuffer(m_KernelIndex, "myLifeTime", m_LifetimeBuffer);
        m_Material.SetBuffer(s_PositionBufferName, m_PositionBuffer);
        m_Material.SetBuffer("myScale", m_ScaleBuffer);
        m_Material.SetBuffer("myVelocity", m_VelocityBuffer);
        m_Material.SetBuffer("myColor", m_ColorBuffer);
        m_Material.SetBuffer("myLifeTime", m_LifetimeBuffer);

        string memSize = GetReadableSize(amount * totalStrideSize);
        Debug.Log($"Alloc GPU memory : total : {memSize}, stride = {totalStrideSize}");
    }

    private void FreeMemory()
    {
        if (m_Tex)
        {
            m_Tex.Release();
            m_Tex = null;
        }
        m_PositionBuffer.Dispose(); m_PositionBuffer = null;
        m_ScaleBuffer.Dispose();    m_ScaleBuffer = null;
        m_VelocityBuffer.Dispose(); m_VelocityBuffer = null;
        m_ColorBuffer.Dispose();    m_ColorBuffer = null;
        m_LifetimeBuffer.Dispose(); m_LifetimeBuffer = null;
        m_MeshTriangles.Dispose();  m_MeshTriangles = null;
        m_MeshVertices.Dispose();   m_MeshVertices = null;
    }
}
