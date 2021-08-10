using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace Kit
{
	/// <summary>Enumeration describing the relationship between a point's handles
	/// 	- Connected : The point's handles are mirrored across the point
	/// 	- Broken : Each handle moves independently of the other
	/// 	- None : This point has no handles (both handles are located ON the point)
	/// </summary>
	public enum eTangentType
	{
		Connected = 0,
		Broken,
		None,
	}

	public interface ITangentPoint
    {
		eTangentType tangentType { get; }
		Quaternion tangentRotation { get; }
		Vector3 localInTangentPoint { get; }
		Vector3 inTangentPoint { get; }
		Vector3 localOutTangentPoint { get; }
		Vector3 outTangentPoint { get; }

		Vector3 position { get; }
		Quaternion rotation { get; }
	}
}