using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class GPUGraph : MonoBehaviour
{
    [SerializeField] Mesh m_Mesh;
    [SerializeField] Material m_Material;
    [SerializeField] ComputeShader m_Shader;
    [SerializeField] int m_ParticleAmount = 1000;

    // to define how to dispatch job to GPU,
    [SerializeField] Vector3Int m_ThreadGroup = new Vector3Int(8,8,1);

    [Header("Draw Bound")]
    [SerializeField] Vector3 m_Offset = Vector3.zero;
    [SerializeField] Vector3 m_Size = Vector3.one;
    [SerializeField] MeshTopology m_MeshTopology = MeshTopology.Points;


    [SerializeField] bool m_GizmosDebug = false;

    Bounds GetDrawBounds()
    {
        return new Bounds
        {
            center = transform.TransformPoint(m_Offset),
            size = m_Size
        };
    }
    ComputeBuffer m_ParticleBuffer, m_MeshTriangles, m_MeshVertices;
    RenderTexture m_Tex;
    int m_KernelIndex;
    const string s_FunctionKernal = "FunctionKernel";
    const string s_ParticlesBufferName = "myParticles";
    const string s_TrianglesBufferName = "myTriangles";
    const string s_VerticesBufferName = "myVertices";
    const string s_DeltaTime = "deltaTime";

    #region System
    private void OnValidate()
    {
        if (m_Material == null)
        {
            var rend = GetComponent<Renderer>();
            if (rend)
                m_Material = rend.sharedMaterial;
        }
        OnEnable();
    }

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
        m_Shader.SetFloat(s_DeltaTime, GetDeltaTime());
        m_Shader.Dispatch(m_KernelIndex, m_ThreadGroup.x, m_ThreadGroup.y, m_ThreadGroup.z);
    }

    private void OnRenderObject()
    {
        if (m_Material)
            Graphics.DrawProcedural(m_Material, GetDrawBounds(), m_MeshTopology, m_MeshTriangles.count, m_ParticleAmount);
    }

    private void OnDrawGizmos()
    {
        if (!m_GizmosDebug)
            return;
        if (m_ParticleBuffer == null)
            return;
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
    #endregion System

    #region Particle data structure and stride size
    public struct Particle
    {
        public Vector3 position;
        // public Vector3 scale;
        public Vector3 velocity;
        public Color color;
        public float lifetime;
    };
    private Particle[]
        m_InitData, // should only use for init. stay global for debug purpose.
        m_OutputData; // for debug purpose.

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
        if (m_ParticleBuffer == null)
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
                m_InitData[i].position = Random.insideUnitSphere;
                m_InitData[i].velocity = Random.insideUnitSphere;
                m_InitData[i].color = Random.ColorHSV();
            }
            m_ParticleBuffer.SetData(m_InitData);
        }

        {
            int[] triangles = m_Mesh.triangles;
            m_MeshTriangles = new ComputeBuffer(triangles.Length, sizeof(float) * 3);
            m_MeshTriangles.SetData(triangles);
        }

        {
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
        
        m_Material.SetBuffer(s_ParticlesBufferName, m_ParticleBuffer);
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
        //m_ParticleBuffer.Release();
        m_ParticleBuffer.Dispose();
        //m_ParticleBuffer = null;

        m_MeshTriangles.Dispose();
        m_MeshVertices.Dispose();
    }
    private float GetDeltaTime()
    {
        if (Application.isPlaying)
            return Time.deltaTime;
#if UNITY_EDITOR
        double t = UnityEditor.EditorApplication.timeSinceStartup - m_EditorTimeSinceStartUp;
        m_EditorTimeSinceStartUp = UnityEditor.EditorApplication.timeSinceStartup;
        return (float)t;
#else
        throw new System.Exception();
#endif
    }
#if UNITY_EDITOR
    private double m_EditorTimeSinceStartUp = 0f;
#endif
}
