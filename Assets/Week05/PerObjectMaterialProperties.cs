using UnityEngine;

[DisallowMultipleComponent]
public class PerObjectMaterialProperties : MonoBehaviour
{

	static int baseColorId = Shader.PropertyToID("_BaseColor");
	static int cutoffId = Shader.PropertyToID("_Cutoff");

	static MaterialPropertyBlock block;

	[SerializeField] Color baseColor = Color.white;
	[SerializeField, Range(0f, 1f)] float cutoff = 0.5f;
	[SerializeField] bool m_RandomColor = false;

	void OnValidate()
	{
		if (block == null)
		{
			block = new MaterialPropertyBlock();
		}
		if (m_RandomColor)
        {
			m_RandomColor = false;
			baseColor = new Color(Random.value, Random.value, Random.value, 1f);
		}

		block.SetColor(baseColorId, baseColor);
		block.SetFloat(cutoffId, cutoff);

		GetComponent<Renderer>().SetPropertyBlock(block);
	}
	void Awake()
	{
		OnValidate();
	}
}