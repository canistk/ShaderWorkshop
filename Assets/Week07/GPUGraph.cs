using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class GPUGraph : MonoBehaviour
{
    [SerializeField] ComputeShader m_Shader;
    [SerializeField] Material m_Mat;
    [SerializeField] int m_ParticleAmount = 1000;
    ComputeBuffer m_Particle;
    RenderTexture m_Tex;

    private void OnValidate()
    {
        if (m_Mat == null)
        {
            var rend = GetComponent<Renderer>();
            if (rend)
                m_Mat = rend.sharedMaterial;
        }
        OnEnable();
    }

    private void OnEnable()
    {
        RunShader();
    }

    private void OnDisable()
    {
        if (m_Tex)
        {
            m_Tex.Release();
            m_Tex = null;
        }
        m_Particle.Release();
        m_Particle.Dispose();
        m_Particle = null;
    }

    public struct Particle
    {
        public Vector3 position;
        public Vector3 scale;
        public Vector3 velocity;
        public Color color;
        public float lifetime;
    };
    private Particle[] m_Buffer;

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

    void RunShader()
    {
        if (!(m_Shader && m_Mat))
            return;


        if (m_Particle == null)
        {
            // float = 1 x 4 byte = 4 stride,
            // Vector3 = 3 x 4 bytes = 12stride
            int sizeOfFloat = sizeof(float);
            int sizeOfVector3 = 3 * sizeOfFloat;
            int sizeOfColor = 4 * sizeOfFloat;
            int stride = sizeOfVector3 + sizeOfColor + sizeOfFloat;

            string memSize = GetReadableSize(stride * m_ParticleAmount);

            Debug.Log($"Alloc GPU memory : stride = {stride}, total : {memSize}");
            m_Particle = new ComputeBuffer(m_ParticleAmount, stride);

            m_Buffer = new Particle[m_ParticleAmount];

            for (int i = 0; i < m_Buffer.Length; i++)
            {
                m_Buffer[i] = new Particle();
                m_Buffer[i].position = Random.insideUnitCircle * 10f;
                m_Buffer[i].velocity = Vector2.zero;
            }
            m_Particle.SetData(m_Buffer);
        }

        if (m_Tex == null)
        {
            m_Tex = new RenderTexture(256, 256, 24);
            m_Tex.enableRandomWrite = true;
            m_Tex.Create();
        }
        m_Mat.SetTexture("_BaseMap", m_Tex);
        //m_Mat.SetVector("_Color", m_Color);

        int kernelIndex = m_Shader.FindKernel("FunctionKernel");
        if (kernelIndex < 0)
        {
            Debug.LogError($"Fail to init kernel");
            return;
        }
        Debug.Log($"Kernel {kernelIndex}");
        m_Shader.SetBuffer(kernelIndex, "Particles", m_Particle);
        m_Mat.SetBuffer("Particles", m_Particle);
        m_Shader.SetTexture(kernelIndex, "Result", m_Tex);
        // m_Shader.GetKernelThreadGroupSizes(kernelHandler, out var xs, out var ys, out var zs);
        // Debug.Log($"X {xs}, Y {ys}, Z {zs}");
        m_Shader.Dispatch(kernelIndex, 256 / 8, 256 / 8, 1);
    }
}
