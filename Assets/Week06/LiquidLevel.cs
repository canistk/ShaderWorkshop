using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class LiquidLevel : MonoBehaviour
{
    public Renderer m_Renderer = null;
    private MaterialPropertyBlock m_Block = null;
    [Header("Shader params")]
    [SerializeField] string m_WobbleX = "_WobbleX";
    [SerializeField] string m_WobbleZ = "_WobbleZ";

    [Range(-1f,1f)] public float m_WobbleAmountX, m_WobbleAmountZ;

    [Header("Behavior")]
    public float m_MaxWobble = 0.03f;
    public float m_WobbleSpeed = 1f;
    public float m_Recovery = 1f;
    Vector3 lastPos, lastRot;
    float wobbleAmountToAddX, wobbleAmountToAddZ;
    float m_Time = 0.5f;

    private int m_WobbleXHash, m_WobbleZHash;

    private void OnValidate()
    {
        m_WobbleXHash = Shader.PropertyToID(m_WobbleX);
        m_WobbleZHash = Shader.PropertyToID(m_WobbleZ);
    }

    void Update()
    {
        if (m_Renderer == null)
            return;
        if (m_Block == null)
        {
            m_Block = new MaterialPropertyBlock();
            m_WobbleXHash = Shader.PropertyToID(m_WobbleX);
            m_WobbleZHash = Shader.PropertyToID(m_WobbleZ);
        }


        if (Application.isPlaying)
            Calculate();
        m_Block.SetFloat(m_WobbleXHash, m_WobbleAmountX);
        m_Block.SetFloat(m_WobbleZHash, m_WobbleAmountZ);
        m_Renderer.SetPropertyBlock(m_Block);
    }

    void Calculate()
    {

        float deltaTime = Time.deltaTime * Time.timeScale;
        m_Time += deltaTime;
        // decrease wobble over time
        float recovery = deltaTime * m_Recovery;
        wobbleAmountToAddX = Mathf.Lerp(wobbleAmountToAddX, 0f, recovery);
        wobbleAmountToAddZ = Mathf.Lerp(wobbleAmountToAddZ, 0f, recovery);

        // make a sine wave of the decreasing wobble
        float pulse = 2f * Mathf.PI * m_WobbleSpeed;
        float pulseTime = Mathf.Sin(pulse * m_Time);
        m_WobbleAmountX = wobbleAmountToAddX * pulseTime;
        m_WobbleAmountZ = wobbleAmountToAddZ * pulseTime;

        // velocity
        Vector3 velocity = (lastPos - transform.position) / deltaTime;
        Vector3 angularVelocity = transform.rotation.eulerAngles - lastRot;

        // add clamped velocity to wobble
        wobbleAmountToAddX += Mathf.Clamp((velocity.x + (angularVelocity.z * 0.2f)) * m_MaxWobble, -m_MaxWobble, m_MaxWobble);
        wobbleAmountToAddZ += Mathf.Clamp((velocity.z + (angularVelocity.x * 0.2f)) * m_MaxWobble, -m_MaxWobble, m_MaxWobble);

        // keep last position
        lastPos = transform.position;
        lastRot = transform.rotation.eulerAngles;
    }
}
