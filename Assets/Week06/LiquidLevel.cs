using System.Collections;
using System.Collections.Generic;
using UnityEngine;
[SelectionBase]
[ExecuteInEditMode]
public class LiquidLevel : MonoBehaviour
{
    public Renderer m_Renderer = null;
    private MaterialPropertyBlock m_Block = null;
    [Header("Shader params")]
    [SerializeField] string m_WobbleX = "_WobbleX";
    [SerializeField] string m_WobbleZ = "_WobbleZ";
    [SerializeField] string m_LiquidLevel = "_LiquidLevel";
    [SerializeField] string m_RotationHotfix = "_RotationHotfix";

    [Header("Liquid Level")]
    [SerializeField] bool m_FeedPivotY = true;
    [SerializeField] bool m_FeedRotationFix = true;
    [Tooltip("Downward = -1, Upward = 1, Vector dot")]
    // [RectRange(-1f, 1f)]
    [SerializeField] AnimationCurve m_RotationAdjust = AnimationCurve.Linear(-1f, -0.2f, 1f, 0.8f);
    [SerializeField] float m_AdjustmentMultiplier = 1f;

    [Range(-1f,1f)] public float m_WobbleAmountX, m_WobbleAmountZ;

    [Header("Behavior")]
    public float m_MaxWobble = 0.03f;
    public float m_WobbleSpeed = 1f;
    public float m_Recovery = 1f;
    Vector3 lastPos;
    Quaternion lastRot = Quaternion.identity;
    float wobbleAmountToAddX, wobbleAmountToAddZ;
    float m_Time = 0.5f;

    private int m_WobbleXHash, m_WobbleZHash, m_LiquidLevelHash, m_RotationHotfixHash;

    private void OnValidate()
    {
        UpdateHash();
    }

    private void UpdateHash()
    {
        m_WobbleXHash = Shader.PropertyToID(m_WobbleX);
        m_WobbleZHash = Shader.PropertyToID(m_WobbleZ);
        m_LiquidLevelHash = Shader.PropertyToID(m_LiquidLevel);
        m_RotationHotfixHash = Shader.PropertyToID(m_RotationHotfix);
    }

    void FixedUpdate()
    {
        if (m_Renderer == null)
            return;
        if (m_Block == null)
        {
            m_Block = new MaterialPropertyBlock();
            UpdateHash();
        }


        if (Application.isPlaying)
        {
            WoobleCalculate();
            m_Block.SetFloat(m_WobbleXHash, m_WobbleAmountX);
            m_Block.SetFloat(m_WobbleZHash, m_WobbleAmountZ);

            if (m_FeedPivotY)
                m_Block.SetFloat(m_LiquidLevelHash, transform.position.y);
            if (m_FeedRotationFix)
            {
                float upwardDot = Vector3.Dot(transform.up, Vector3.up); // -1 ~ 1
                float liquidLevelBias = m_AdjustmentMultiplier * m_RotationAdjust.Evaluate(upwardDot);
                m_Block.SetFloat(m_RotationHotfixHash, liquidLevelBias);
            }
        }

        m_Renderer.SetPropertyBlock(m_Block);
    }

    void WoobleCalculate()
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
        Quaternion rotDiff = Quaternion.Inverse(lastRot) * transform.rotation;
        Vector3 angularVelocity = rotDiff.eulerAngles;

        // add clamped velocity to wobble
        wobbleAmountToAddX += Mathf.Clamp((velocity.x + (angularVelocity.z * 0.2f)) * m_MaxWobble, -m_MaxWobble, m_MaxWobble);
        wobbleAmountToAddZ += Mathf.Clamp((velocity.z + (angularVelocity.x * 0.2f)) * m_MaxWobble, -m_MaxWobble, m_MaxWobble);

        // keep last position
        lastPos = transform.position;
        lastRot = transform.rotation;
    }
}
