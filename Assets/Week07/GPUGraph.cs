using System.Collections;
using System.Collections.Generic;
using UnityEngine;
/// <summary>
/// https://github.com/SimpleTalkCpp/workshop-2021-07-unity-shader/tree/main/Assets/Week007
/// </summary>
[ExecuteInEditMode]
public class GPUGraph : MonoBehaviour
{
    [SerializeField] Mesh m_Mesh;
    [SerializeField] Material m_Material;
    [SerializeField] ComputeShader m_Shader;
    [SerializeField] int m_ParticleAmount = 1000;
    [SerializeField] Vector3 m_ParticleScale = Vector3.one;
    [SerializeField] Vector2 m_LifeTimeRange = new Vector2(3f, 5f);

    // to define how to dispatch job to GPU,
    [SerializeField] Vector3Int m_ThreadGroup = new Vector3Int(8,8,1);


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
    ComputeBuffer m_ParticleBuffer, m_MeshTriangles, m_MeshVertices, m_PositionBuffer, m_VelocityBuffer;
    RenderTexture m_Tex;
    int m_KernelIndex;
    const string s_FunctionKernal = "FunctionKernel";
    static int s_ParticlesBufferName = Shader.PropertyToID("myParticles");

    static int s_PositionBufferName = Shader.PropertyToID("myPosition");
    static int s_VelocityBufferName = Shader.PropertyToID("myVelocity");
    static int s_TrianglesBufferName = Shader.PropertyToID("myTriangles");
    static int s_VerticesBufferName = Shader.PropertyToID("myVertices");
    static int s_DeltaTime = Shader.PropertyToID("deltaTime");

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
        m_Material.SetBuffer(s_PositionBufferName, m_PositionBuffer);
        m_Material.SetBuffer(s_VelocityBufferName, m_VelocityBuffer);
        m_Material.SetBuffer(s_ParticlesBufferName, m_ParticleBuffer);

        m_Shader.SetFloat(s_DeltaTime, Time.deltaTime);
        m_Shader.Dispatch(m_KernelIndex, m_ThreadGroup.x, m_ThreadGroup.y, m_ThreadGroup.z);
        if (m_Material && m_ParticleAmount > 0)
            Graphics.DrawProcedural(m_Material, GetDrawBounds(), MeshTopology.Triangles, m_MeshTriangles.count, m_ParticleAmount);
        //Graphics.DrawMeshInstancedProcedural(m_Mesh, 0, m_Material, GetDrawBounds(), m_ParticleAmount);
    }

    private void OnDrawGizmos()
    {
        if (!m_GizmosDebug)
            return;
        if (m_ParticleBuffer != null && m_ParticleBuffer.IsValid())
        {
            m_ParticleBuffer.GetData(m_OutputData);
            if (m_OutputData == null)
                return;

            Color old = Gizmos.color;
            foreach (var p in m_OutputData)
            {
                Gizmos.color = p.color;
                Gizmos.DrawSphere(p.position, 0.05f);
            }
            Gizmos.color = old;
        }
        if (m_PositionBuffer != null && m_PositionBuffer.IsValid())
        {
            m_PositionBuffer.GetData(m_Positions);
            if (m_Positions == null)
                return;
            Color old = Gizmos.color;
            foreach (var p in m_Positions)
            {
                Gizmos.DrawWireCube(p, Vector3.one * 0.1f);
            }
            Gizmos.color = old;
        }

    }
    #endregion System

    #region Particle data structure and stride size
    public struct Particle
    {
        public Vector3 position;
        public Vector3 scale;
        public Vector3 velocity;
        public Color color;
        public float lifetime;
    };
    private Particle[]
        m_InitData, // should only use for init. stay global for debug purpose.
        m_OutputData; // for debug purpose.
    private Vector3[] m_Positions;
    private int CalStrideSize()
    {
        // float = 1 x 4 byte = 4 stride,
        // Vector3 = 3 x 4 bytes = 12 stride
#if true
        return System.Runtime.InteropServices.Marshal.SizeOf(typeof(Particle));
#else
        int sizeOfFloat = sizeof(float);
        int sizeOfVector3 = 3 * sizeOfFloat;
        int sizeOfColor = 4 * sizeOfFloat;
        int stride = 3 * sizeOfVector3 + sizeOfColor + sizeOfFloat;
        Debug.Log("Stride = " + stride);
        return stride;
#endif
    }
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


        /// Init particle buffer
        if (m_ParticleBuffer == null || !m_ParticleBuffer.IsValid())
        {
            int stride = CalStrideSize();
            string memSize = GetReadableSize(m_ParticleAmount * stride);
            Debug.Log($"Alloc GPU memory : total : {memSize}, stride = {stride}");
            m_ParticleBuffer = new ComputeBuffer(m_ParticleAmount, stride);

            m_InitData = new Particle[m_ParticleAmount];
            m_OutputData = new Particle[m_ParticleAmount];
            for (int i = 0; i < m_InitData.Length; i++)
            {
                m_InitData[i] = new Particle();
                m_InitData[i].position = new Vector3(i, 0, 0);
                m_InitData[i].scale = m_ParticleScale;
                m_InitData[i].velocity = new Vector3(0, 1f, 0);
                m_InitData[i].color = Random.ColorHSV();
                m_InitData[i].lifetime = Random.Range(m_LifeTimeRange.x, m_LifeTimeRange.y);
            }
            m_ParticleBuffer.SetData(m_InitData);
        }

        if (m_PositionBuffer == null || !m_PositionBuffer.IsValid())
        {
            m_Positions = new Vector3[m_ParticleAmount];
            for (int i = 0; i < m_Positions.Length; i++)
            {
                m_Positions[i] = new Vector3(i, 0f, 0f);
            }
            m_PositionBuffer = new ComputeBuffer(m_ParticleAmount, 3 * 4);
            m_PositionBuffer.SetData(m_Positions);
        }

        if (m_VelocityBuffer == null || !m_VelocityBuffer.IsValid())
        {
            var arr = new Vector3[m_ParticleAmount];
            for (int i = 0; i < arr.Length; i++)
            {
                arr[i] = new Vector3(0f, 1f, 0f);
            }
            m_VelocityBuffer = new ComputeBuffer(m_ParticleAmount, 3 * 4);
            m_VelocityBuffer.SetData(arr);
        }

        if (m_Mesh)
        {
            int[] triangles = m_Mesh.triangles;
            m_MeshTriangles = new ComputeBuffer(triangles.Length, sizeof(float) * 3);
            m_MeshTriangles.SetData(triangles);

            Vector3[] positions = m_Mesh.vertices;
            m_MeshVertices = new ComputeBuffer(positions.Length, sizeof(float) * 3);
            m_MeshVertices.SetData(positions);
        }
        
        m_KernelIndex = m_Shader.FindKernel(s_FunctionKernal);
        if (m_KernelIndex < 0)
        {
            Debug.LogError($"Fail to init kernel");
            return;
        }
        m_Shader.GetKernelThreadGroupSizes(m_KernelIndex, out var _x, out var _y, out var _z);
        Debug.Log($"Kernel {m_KernelIndex}, ThreadGroupSize : X {_x}, Y {_y}, Z {_z}");
        
        m_Shader.SetBuffer(m_KernelIndex, s_ParticlesBufferName, m_ParticleBuffer);
        m_Shader.SetBuffer(m_KernelIndex, s_PositionBufferName, m_PositionBuffer);
        m_Shader.SetBuffer(m_KernelIndex, s_VelocityBufferName, m_VelocityBuffer);

        m_Material.SetBuffer(s_TrianglesBufferName, m_MeshTriangles);
        m_Material.SetBuffer(s_VerticesBufferName, m_MeshVertices);
    }
    private void FreeMemory()
    {
        if (m_Tex)
        {
            m_Tex.Release();
            m_Tex = null;
        }
        m_ParticleBuffer.Dispose(); m_ParticleBuffer = null;
        m_PositionBuffer.Dispose(); m_PositionBuffer = null;
        m_VelocityBuffer.Dispose(); m_VelocityBuffer = null;
        m_MeshTriangles.Dispose(); m_MeshTriangles = null;
        m_MeshVertices.Dispose(); m_MeshVertices = null;
    }
}
