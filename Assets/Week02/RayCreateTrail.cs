using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using Kit;
using Kit.Coordinates;

public class RayCreateTrail : MonoBehaviour
{
    [SerializeField] Camera m_Camera = null;
    [SerializeField] Transform m_Token = null;
    [SerializeField] Transform m_TrailParent = null;
    [SerializeField] float m_Speed = 1f;

    [Header("Physic")]
    [SerializeField] float m_Radius = 0.5f;
    [SerializeField] float m_MaxDistance = 1000f;
    [SerializeField] LayerMask m_LayerMask = Physics.DefaultRaycastLayers;
    [SerializeField] QueryTriggerInteraction m_QueryTriggerInteraction = QueryTriggerInteraction.Ignore;

    [Header("History")]
    [SerializeField] int m_HistorySize = 100;
    [SerializeField] float m_SampleDuration = 2f;

    [Header("Bezier Curve Generation")]
    [SerializeField] bool m_UseTolerance = false;
    // [DrawIf(nameof(m_UseTolerance), false, ComparisonType.Equals, DisablingType.ReadOnly)]
    [SerializeField, Range(3, 30)] int m_Resolution = 10;
    // [DrawIf(nameof(m_UseTolerance),true, ComparisonType.Equals, DisablingType.ReadOnly)]
    [SerializeField] float m_Tolerance = 0.03f;
    [SerializeField, Range(0f, 1f)] float m_TangenRatio = 0.5f;

    [Header("Mesh Generation")]
    [SerializeField] float[] m_Partitions = { 0.2f, 0.8f, 0.2f };
    [SerializeField] AnimationCurve m_PathShape = AnimationCurve.Linear(0f, 0f, 1f, 1f);
    [SerializeField, Range(0, 0.1f)] float m_UpdatePeriod = 0.02f;


    #region System

    private void OnValidate()
    {
        if (m_History != null && m_History.Length != m_HistorySize)
        {
            System.Array.Resize(ref m_History, m_HistorySize);
            m_WritePt = 0;
        }
    }
    private void Awake()
    {
        if (m_Camera == null)
            m_Camera = Camera.main;
        if (m_Token == null)
            m_Token = transform;
        InitHistory();
    }

    private void OnEnable()
    {
        StartCoroutine(PeriodicUpdate());
    }

    private void FixedUpdate()
    {
        DefineMoveablePosition();
    }

    private void Update()
    {
        ContinueTokenMovement();
    }

    private IEnumerator PeriodicUpdate()
    {
        yield return new WaitUntil(() => m_FirstHit);
        Vector3 lastPos = m_Token.position;
        while (true)
        {
            if (lastPos != m_Token.position)
                Record(new MotionRecord(m_Token.position, m_Token.rotation, Time.deltaTime * Time.timeScale));
            GenerateMesh();
            if (m_UpdatePeriod < float.Epsilon)
                yield return null;
            else
                yield return new WaitForSeconds(m_UpdatePeriod);
        }
    }

    #endregion System

    #region History
    private MotionRecord[] m_History;
    private int m_WritePt = 0;
    public struct MotionRecord
    {
        public bool IsValid;
        public Vector3 position;
        public Quaternion rotation;
        public float deltaTime;
        public float timeSinceLevelLoad;
        public MotionRecord(Vector3 _position, Quaternion _rotation, float _deltaTime)
        {
            position = _position;
            rotation = _rotation;
            deltaTime = _deltaTime;
            IsValid = true;
            timeSinceLevelLoad = Time.timeSinceLevelLoad;
        }
    }
    private void InitHistory()
    {
        if (m_History == null)
        {
            m_History = new MotionRecord[m_HistorySize];
            m_WritePt = 0;
        }
    }

    private void Record(MotionRecord motion)
    {
        m_History[m_WritePt] = motion;
        m_WritePt = (m_WritePt + 1) % m_History.Length;
    }

    public Vector3[] GetPositionInPeriod(float secondAgo)
    {
        List<Vector3> list = new List<Vector3>(m_HistorySize);
        foreach (MotionRecord r in GetPeriod(secondAgo))
            list.Add(r.position);

        return list.ToArray();
    }

    public IEnumerable<MotionRecord> GetPeriod(float secondAgo)
    {
        secondAgo = Mathf.Max(0f, secondAgo);
        int pt = m_WritePt;
        float timePassed = 0f;
        int cnt = 0;
        do
        {
            pt = (pt + m_History.Length - 1) % m_History.Length;
            if (!m_History[pt].IsValid)
                yield break;
            timePassed += m_History[pt].deltaTime;
            cnt++;
            yield return m_History[pt];
        }
        while (pt != m_WritePt && timePassed < secondAgo);
        // Debug.Log($"{nameof(GetPeriod)}, timePass {timePassed:F2}, record(s) {cnt}");
    }

    public IEnumerable<MotionRecord> GetHistory()
    {
        int pt = m_WritePt;
        do
        {
            pt = (pt + m_History.Length - 1) % m_History.Length;
            yield return m_History[pt];
        }
        while (pt != m_WritePt);
    }

    #endregion History

    #region Generate Mesh
    Mesh m_Mesh;
    MeshFilter m_MeshFilter;
    MeshRenderer m_MeshRenderer;
    [SerializeField] Bezier.Baked m_Baked;
    bool m_EmptyDistanceFlag = true;
    private void GenerateMesh()
    {
        List<Bezier.PosRotateTime> pr = new List<Bezier.PosRotateTime>(m_HistorySize);
        foreach (var data in GetPeriod(m_SampleDuration))
        {
            pr.Add(new Bezier.PosRotateTime(data.position, data.rotation, data.timeSinceLevelLoad));
        }
        if (m_UseTolerance)
            m_Baked = Bezier.BakeCurveByTolerance(m_TrailParent, pr, m_TangenRatio, m_Tolerance);
        else
            m_Baked = Bezier.BakeCurveByResolution(m_TrailParent, pr, m_TangenRatio, m_Resolution);
        pr.Clear();
        if (!m_EmptyDistanceFlag || m_Baked.totalDistance > float.Epsilon)
        {
            Bezier.GenerateCurveMesh("Trail", m_Partitions, m_Baked, m_PathShape, ref m_Mesh);
        }

        m_EmptyDistanceFlag = m_Baked.totalDistance < float.Epsilon;
        if (m_MeshFilter == null)
            m_MeshFilter = m_TrailParent.GetComponent<MeshFilter>();
        if (m_MeshFilter == null)
            m_MeshFilter = m_TrailParent.gameObject.AddComponent<MeshFilter>();
        if (m_MeshRenderer == null)
            m_MeshRenderer = m_TrailParent.GetComponent<MeshRenderer>();
        if (m_MeshRenderer == null)
            m_MeshRenderer = m_TrailParent.gameObject.AddComponent<MeshRenderer>();
        m_MeshFilter.mesh = m_Mesh;
    }
    #endregion Generate Mesh

    #region Raycast & Movement
    RaycastHit m_HitInfo;
    bool m_FirstHit = false;
    Vector3 m_LastPosition;
    Vector3 m_NextPosition;
    private void DefineMoveablePosition()
    {
        if (!Input.GetMouseButton(0))
            return;

        Ray ray = m_Camera.ScreenPointToRay(Input.mousePosition);
        if (Physics.SphereCast(ray, m_Radius,
            out m_HitInfo, m_MaxDistance, m_LayerMask, m_QueryTriggerInteraction))
        {
            m_NextPosition = ray.origin + ray.direction * m_HitInfo.distance;
            if (!m_FirstHit)
            {
                m_FirstHit = true;
                
                m_Token.position = m_LastPosition = m_NextPosition;
            }
        }
    }

    private void ContinueTokenMovement()
    {
        if (!m_FirstHit)
            return;

        Vector3 v = m_NextPosition - m_LastPosition;
        float distance = v.magnitude;
        float moveableDistance = m_Speed * Time.deltaTime * Time.timeScale;
        if (distance <= moveableDistance)
        {
            m_LastPosition = m_Token.position = m_NextPosition;
        }
        else
        {
            if (v != Vector3.zero)
            {
                Quaternion wanted = Quaternion.LookRotation(v, m_Token.up);
                // m_Token.rotation = Quaternion.RotateTowards(m_Token.rotation, wanted, m_AngularSpeed);
                m_Token.rotation = Quaternion.Slerp(m_Token.rotation, wanted, 0.5f);
            }
            Vector3 deltaPos = m_LastPosition + (v / distance) * moveableDistance;
            m_LastPosition = m_Token.position = deltaPos;
        }
    }
    #endregion Raycast & Movement
}
