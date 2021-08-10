using UnityEngine;
using System.Collections;
using System.Collections.Generic;
namespace Kit.Coordinates
{
	/// <summary>Bezier</summary>
	/// <remarks>
	/// <see cref="http://answers.unity3d.com/questions/12689/moving-an-object-along-a-bezier-curve.html"/>
	/// <seealso cref="http://www.theappguruz.com/blog/bezier-curve-in-games"/>
	/// </remarks>
	public static class Bezier
	{
        #region Bezier Tools
        private static /* readonly */ Vector3 Vector3zero = Vector3.zero;
		private static /* readonly */ Vector3 Vector3forward = Vector3.forward;
		private static /* readonly */ Vector3 Vector3back = Vector3.back;
		private static /* readonly */ Quaternion Quaternionidentity = Quaternion.identity;

		[System.Obsolete("Too hard to merge second-order & third-order result.")]
		/// <summary>Gets the point percent along a second-order curve</summary>
		/// <param name="start"></param>
		/// <param name="control"></param>
		/// <param name="end"></param>
		/// <param name="percent"></param>
		/// <returns>The point percent along the curve</returns>
		/// <remarks>Quadratic bezier in 3D</remarks>
		public static Vector3 Lerp(Vector3 start, Vector3 control, Vector3 end, float percent)
		{
			percent = Mathf.Clamp01(percent);
			float np = 1f - percent;
			// return (Mathf.Pow(1f - percent, 2f) * start) + (2f * (1f - percent) * percent * control) + (Mathf.Pow(percent, 2f) * end);
			return (np * np * start) + (2f * np * percent * control) + (percent * percent * end);
		}

		/// <summary>Gets the point of percent along a third-order curve</summary>
		/// <param name='start'>The point at the beginning of the curve</param>
		/// <param name='startTangent'>The second point along the curve</param>
		/// <param name='endTangent'>The third point along the curve</param>
		/// <param name='end'>The point at the end of the curve</param>
		/// <param name='percent'>Value between 0 and 1 representing the percent along the curve (0 = 0%, 1 = 100%)</param>
		/// <returns>The point percent along the curve</returns>
		/// <remarks>Cubic Curve in 3D</remarks>
		public static Vector3 Lerp(Vector3 start, Vector3 startTangent, Vector3 endTangent, Vector3 end, float percent)
		{
			percent = Mathf.Clamp01(percent);
			float np = 1f - percent;

			Vector3
				// part1 = Mathf.Pow(1f - percent, 3f) * start,
				// part2 = 3f * Mathf.Pow(1f - percent, 2f) * percent * startTangent,
				// part3 = 3f * (1f - percent) * Mathf.Pow(percent, 2f) * endTangent,
				// part4 = Mathf.Pow(percent, 3) * end;
				part1 = np * np * np * start,
				part2 = 3f * np * np * percent * startTangent,
				part3 = 3f * np * percent * percent * endTangent,
				part4 = percent * percent * percent * end;

			return part1 + part2 + part3 + part4;
		}

		/// <summary>Gets the point percent along a curve. Automatically calculates for the number of relevant points</summary>
		/// <returns>The point percent along the curve</returns>
		/// <param name='start'>The bezier point at the beginning of the curve</param>
		/// <param name='end'>The bezier point at the end of the curve</param>
		/// <param name='percent'>Value between 0 and 1 representing the percent along the curve (0 = 0%, 1 = 100%)</param>
		public static Vector3 Lerp(ITangentPoint start, ITangentPoint end, float percent)
		{
			if ((start.tangentType == eTangentType.None && end.tangentType == eTangentType.None) ||
				(start.localOutTangentPoint == Vector3zero && end.localInTangentPoint == Vector3zero))
				return Vector3.Lerp(start.position, end.position, percent);
			else
				return Bezier.Lerp(start.position, start.outTangentPoint, end.inTangentPoint, end.position, percent);
		}

		/// <summary>Locate the tangent point of giving bezier curve.
		/// <see cref="https://pages.mtu.edu/~shene/COURSES/cs3621/NOTES/spline/Bezier/bezier-sub.html"/>
		/// </summary>
		/// <param name="start"></param>
		/// <param name="end"></param>
		/// <param name="percentage"></param>
		/// <param name="splitPoint"></param>
		/// <param name="tangent00"></param>
		/// <param name="tangent01"></param>
		public static void LocateSplitTangentPoint(ITangentPoint start, ITangentPoint end, float percentage,
			out Vector3 splitPoint, out Vector3 tangent00, out Vector3 tangent01)
		{
			LocateSplitTangentPoint(start.position, start.outTangentPoint, end.inTangentPoint, end.position, percentage,
				out splitPoint, out tangent00, out tangent01);
		}
		public static void LocateSplitTangentPoint(Vector3 start, Vector3 startOutTangentPoint, Vector3 endInTangentPoint, Vector3 end, float percentage,
			out Vector3 splitPoint, out Vector3 tangent00, out Vector3 tangent01)
        {
			percentage = Mathf.Clamp01(percentage);
			Vector3 p10 = Vector3.LerpUnclamped(start, startOutTangentPoint, percentage);
			Vector3 p11 = Vector3.LerpUnclamped(startOutTangentPoint, endInTangentPoint, percentage);
			Vector3 p12 = Vector3.LerpUnclamped(endInTangentPoint, end, percentage);
			tangent00 = Vector3.LerpUnclamped(p10, p11, percentage);
			tangent01 = Vector3.LerpUnclamped(p11, p12, percentage);
			splitPoint = Vector3.LerpUnclamped(tangent00, tangent01, percentage);
		}

		/// <summary>Approximates the length</summary>
		/// <returns>The approximate length</returns>
		/// <param name='start'>The bezier point at the start of the curve</param>
		/// <param name='end'>The bezier point at the end of the curve</param>
		/// <param name='resolution'>The number of points along the curve used to create measurable segments</param>
		public static float ApproximateLength(ITangentPoint start, ITangentPoint end, int resolution)
		{
			float sqrTotal = 0, res = (float)resolution;
			Vector3
				lastPosition = start.position,
				currentPosition;

			for (int i = 0; i < resolution + 1; i++)
			{
				currentPosition = Bezier.Lerp(start, end, ((float)i) / res);
				sqrTotal += (currentPosition - lastPosition).magnitude;
				lastPosition = currentPosition;
			}

			return sqrTotal;
		}

		/// <summary>Approximates the length</summary>
		/// <returns>The approximate length</returns>
		/// <param name='start'>The bezier point at the start of the curve</param>
		/// <param name='end'>The bezier point at the end of the curve</param>
		/// <param name='resolution'>The number of points along the curve used to create measurable segments</param>
		public static float ApproximateLength(Vector3 start, Vector3 startTangent, Vector3 endTangent, Vector3 end, int resolution)
		{
			float sqrTotal = 0, res = (float)resolution;
			Vector3
				lastPosition = start,
				currentPosition;

			for (int i = 0; i < resolution + 1; i++)
			{
				currentPosition = Bezier.Lerp(start, startTangent, endTangent, end, ((float)i) / res);
				sqrTotal += (currentPosition - lastPosition).magnitude;
				lastPosition = currentPosition;
			}

			return sqrTotal;
		}

		/// <summary>Gets point percent along n-order curve</summary>
		/// <returns>The point 't' percent along the curve</returns>
		/// <param name='percent'>Value between 0 and 1 representing the percent along the curve (0 = 0%, 1 = 100%)</param>
		/// <param name='points'>The points used to define the curve</param>
		public static Vector3 GetPoint(float percent, params Vector3[] points)
		{
			percent = Mathf.Clamp01(percent);

			int order = points.Length - 1;
			Vector3
				point = Vector3zero,
				vectorToAdd;

			for (int i = 0; i < points.Length; i++)
			{
				vectorToAdd = points[points.Length - i - 1] * (BinomialCoefficient(i, order) * Mathf.Pow(percent, order - i) * Mathf.Pow((1 - percent), i));
				point += vectorToAdd;
			}

			return point;
		}

		public static float GetNextPercentageBySpeed(float currentPt, float avgSpeed, bool inverse, bool close, float curveLength)
		{
			float oldPt = Bezier.ValidPercentage(currentPt, inverse, close);
			float step = Bezier.ConvertSpeedToPercentage(avgSpeed, curveLength);
			float newPt = inverse ? step - oldPt : step + oldPt;
			if (close)
				newPt = Mathf.Repeat(newPt, 1f);
			else
				newPt = Mathf.Clamp01(newPt);
			return newPt;
		}

		public static float ValidPercentage(float pt, bool inverse, bool close)
		{
			pt = close ? Mathf.Repeat(pt, 1f) : Mathf.Clamp01(pt);
			return inverse ? Mathf.Abs(1f - pt) : pt;
		}

		public static float ConvertSpeedToPercentage(float avgSpeed, float totalCurveLength)
		{
			float deltaTime = Time.deltaTime * Time.timeScale;
			float stepDistance = avgSpeed * deltaTime;
			float stepPt = stepDistance / totalCurveLength;
			return stepPt;
		}

		private static int BinomialCoefficient(int i, int n)
		{
			return Factorial(n) / (Factorial(i) * Factorial(n - i));
		}

		private static int Factorial(int i)
		{
			if (i == 0) return 1;

			int total = 1;

			while (i - 1 >= 0)
			{
				total *= i;
				i--;
			}

			return total;
		}
		#endregion Bezier Tools

		#region Curve Sampling
		const float s_Epsilon = float.Epsilon;
		
		/// <summary>
		/// A buggy function try to convert 4,3,2 points into bezier curve.
		/// Baked Curve into pure data structure.
		/// Aim for reduce the calculation on path length related methods.
		/// Also provide sample for <see cref="GenerateCurveMesh(string, float[], Baked, ref Mesh)"/>
		/// </summary>
		/// <param name="parent"></param>
		/// <param name="tp"></param>
		/// <param name="tolerance"></param>
		/// <returns></returns>
		public static Baked BakeCurveByTolerance(Transform parent, IList<Vector3> tp, float tolerance, IList<Quaternion> rotate = null)
		{
			float totalDistance = 0f;
			List<Session> sessions = new List<Session>(tp.Count);
			for (int i = 0; i < tp.Count;)
			{
				float anchorStartDistance = totalDistance;
				int cnt = tp.Count - i;
				int p0, p1, p2, p3;
				if (cnt <= 1)
				{
					i++; // too little sample
					continue;
				}
				else if (cnt == 2)
				{
					p0 = p1 = i;
					p2 = p3 = i + 1;
					i += 2;
				}
				else if (cnt == 3)
				{
					p0 = i;
					p1 = p2 = i + 1;
					p3 = i + 2;
					i += 3;
				}
				else
				{
					p0 = i;
					p1 = i + 1;
					p2 = i + 2;
					p3 = i + 3;
					i += 4;
				}

				// Avoid calculation 0 length session.
				bool noLength = (tp[p0] - tp[p3]).sqrMagnitude <= s_Epsilon;
				if (noLength)
					continue;

				Vector3 LP0 = parent.InverseTransformPoint(tp[p0]);
				Vector3 LP0Out = parent.InverseTransformPoint(tp[p1]);
				Vector3 LP0In = i > 0 ? parent.InverseTransformPoint(tp[i - 1]) : LP0;
				Quaternion LP0Rot = rotate != null ? Quaternion.Inverse(parent.rotation) * rotate[p0] : Quaternion.LookRotation(tp[p3] - tp[p0]);
				LinkedFragment from = new LinkedFragment
				{
					localInTangent = LP0In,
					localPosition = LP0,
					localOutTangent = LP0Out,
					localRotation = LP0Rot,
					percentage = 0,
				};
				Vector3 LP1 = parent.InverseTransformPoint(tp[p3]);
				Vector3 LP1In = parent.InverseTransformPoint(tp[p2]);
				Vector3 LP1Out = i + 4 < tp.Count ? parent.InverseTransformPoint(tp[i + 4]) : LP1;
				Quaternion LP1Rot = rotate != null? Quaternion.Inverse(parent.rotation) * rotate[p3] : Quaternion.LookRotation(tp[p3] - tp[p0]);
				LinkedFragment to = new LinkedFragment
				{
					localInTangent = LP1In,
					localPosition = LP1,
					localOutTangent = LP1Out,
					localRotation = LP1Rot,
					percentage = 1,
					previous = from,
				};
				from.next = to;
				// DebugExtend.DrawArrow(tp[p0], tp[p3] - tp[p0], Color.red, 0f);

				CalcSampleByTolerance(from, to, 0.5f, tolerance, out Fragment[] fragments, out float length);
				totalDistance += length;
				Session session = new Session
				{
					anchorStartDistance = anchorStartDistance,
					length = length,
					fragments = fragments,
				};
				sessions.Add(session);
			}
			Baked rst = new Baked(parent, sessions, totalDistance);
			return rst;
		}

		/// <summary>
		/// A buggy function try to convert 4,3,2 points into bezier curve.
		/// </summary>
		/// <param name="parent"></param>
		/// <param name="tp"></param>
		/// <param name="resolution"></param>
		/// <param name="rotate"></param>
		/// <returns></returns>
		public static Baked BakeCurveByResolution(Transform parent, IList<Vector3> tp, int resolution, IList<Quaternion> rotate = null)
        {
			if (resolution < 3)
				resolution = 3;
			float totalDistance = 0f;
			List<Session> sessions = new List<Session>(tp.Count);
			for (int i = 0; i < tp.Count;)
			{
				float anchorStartDistance = totalDistance;
				int cnt = tp.Count - i;
				int p0, p1, p2, p3;
				if (cnt <= 1)
				{
					i++; // too little sample
					continue;
				}
				else if (cnt == 2)
				{
					p0 = p1 = i;
					p2 = p3 = i + 1;
					i += 2;
				}
				else if (cnt == 3)
				{
					p0 = i;
					p1 = p2 = i + 1;
					p3 = i + 2;
					i += 3;
				}
				else
				{
					p0 = i;
					p1 = i + 1;
					p2 = i + 2;
					p3 = i + 3;
					i += 4;
				}

				// Avoid calculation 0 length session.
				bool noLength = (tp[p0] - tp[p3]).sqrMagnitude <= s_Epsilon;
				if (noLength)
					continue;

				Vector3 LP0 = parent.InverseTransformPoint(tp[p0]);
				Vector3 LP0Out = parent.InverseTransformPoint(tp[p1]);
				Vector3 LP0In = i > 0 ? parent.InverseTransformPoint(tp[i - 1]) : LP0;
				Quaternion LP0Rot = rotate != null ? Quaternion.Inverse(parent.rotation) * rotate[p0] : Quaternion.LookRotation(tp[p3] - tp[p0]);
				LinkedFragment from = new LinkedFragment
				{
					localInTangent = LP0In,
					localPosition = LP0,
					localOutTangent = LP0Out,
					localRotation = LP0Rot,
					percentage = 0,
				};
				Vector3 LP1 = parent.InverseTransformPoint(tp[p3]);
				Vector3 LP1In = parent.InverseTransformPoint(tp[p2]);
				Vector3 LP1Out = i + 4 < tp.Count ? parent.InverseTransformPoint(tp[i + 4]) : LP1;
				Quaternion LP1Rot = rotate != null ? Quaternion.Inverse(parent.rotation) * rotate[p3] : Quaternion.LookRotation(tp[p3] - tp[p0]);
				LinkedFragment to = new LinkedFragment
				{
					localInTangent = LP1In,
					localPosition = LP1,
					localOutTangent = LP1Out,
					localRotation = LP1Rot,
					percentage = 1,
					previous = from,
				};
				from.next = to;
				// DebugExtend.DrawArrow(tp[p0], tp[p3] - tp[p0], Color.red, 0f);

				_CalcSampleByResolution(from, to, resolution, out Fragment[] fragments, out float length);
				totalDistance += length;
				Session session = new Session
				{
					anchorStartDistance = anchorStartDistance,
					length = length,
					fragments = fragments,
				};
				sessions.Add(session);
			}
			Baked rst = new Baked(parent, sessions, totalDistance);
			return rst;
		}

		/// <summary>Auto setup smooth tangent by giving rotation(Quaternion)</summary>
		/// <param name="parent"></param>
		/// <param name="data"><see cref="Bezier.PosRotateTime"/></param>
		/// <param name="tolerance"></param>
		/// <returns></returns>
		public static Baked BakeCurveByTolerance(Transform parent, IList<PosRotateTime> data, float tangentRatio, float tolerance)
        {
			float totalDistance = 0f;
			List<Session> sessions = new List<Session>(data.Count);
			tangentRatio = Mathf.Clamp01(tangentRatio);
			float lastDistance = 0f;
			for (int i = 1; i < data.Count; i++)
			{
				float distance = (data[i - 1].position - data[i].position).magnitude;
				bool noLength = distance <= s_Epsilon;
				if (noLength)
					continue;

				float anchorStartDistance = totalDistance;
				LinkedFragment from = new LinkedFragment
				{
					localPosition = parent.InverseTransformPoint(data[i - 1].position),
					localRotation = Quaternion.Inverse(parent.rotation) * data[i - 1].rotation,
					localInTangent = parent.InverseTransformPoint(data[i - 1].position + data[i - 1].rotation * Vector3back * (lastDistance * 0.5f * tangentRatio)),
					localOutTangent = parent.InverseTransformPoint(data[i - 1].position + data[i - 1].rotation * Vector3forward * (distance * 0.5f * tangentRatio)),
					timeSinceLevelLoad = data[i - 1].timeSinceLevelLoad,
					percentage = 0,
				};
				lastDistance = distance;
				float nextDistance = i < data.Count - 1 ? (data[i].position - data[i + 1].position).magnitude : 0f;
				LinkedFragment to = new LinkedFragment
				{
					localPosition = parent.InverseTransformPoint(data[i].position),
					localRotation = Quaternion.Inverse(parent.rotation) * data[i].rotation,
					localInTangent = parent.InverseTransformPoint(data[i].position + data[i].rotation * Vector3back * (distance * 0.5f * tangentRatio)),
					localOutTangent = parent.InverseTransformPoint(data[i].position + data[i].rotation * Vector3forward * (nextDistance * 0.5f * tangentRatio)),
					timeSinceLevelLoad = data[i].timeSinceLevelLoad,
					percentage = 1,
					previous = from,
				};
				from.next = to;
				CalcSampleByTolerance(from, to, 0.5f, tolerance, out Fragment[] fragments, out float length);
				totalDistance += length;
				Session session = new Session
				{
					anchorStartDistance = anchorStartDistance,
					length = length,
					fragments = fragments,
				};
				sessions.Add(session);
			}
			return new Baked(parent, sessions, totalDistance);
		}

		/// <summary>Auto setup smooth tangent by giving rotation(Quaternion)</summary>
		/// <param name="parent"></param>
		/// <param name="data"><see cref="Bezier.PosRotateTime"/></param>
		/// <param name="resolution"></param>
		/// <returns></returns>
		public static Baked BakeCurveByResolution(Transform parent, IList<PosRotateTime> data, float tangentRatio, int resolution)
		{
			if (resolution < 3)
				resolution = 3;
			float totalDistance = 0f;
			List<Session> sessions = new List<Session>(data.Count);
			tangentRatio = Mathf.Clamp01(tangentRatio);
			float lastDistance = 0f;
			for (int i = 1; i < data.Count; i++)
			{
				float distance = (data[i - 1].position - data[i].position).magnitude;
				bool noLength = distance <= s_Epsilon;
				if (noLength)
					continue;
				float anchorStartDistance = totalDistance;
				LinkedFragment from = new LinkedFragment
				{
					localPosition = parent.InverseTransformPoint(data[i - 1].position),
					localRotation = Quaternion.Inverse(parent.rotation) * data[i - 1].rotation,
					localInTangent = parent.InverseTransformPoint(data[i - 1].position + data[i - 1].rotation * Vector3back * (lastDistance * 0.5f * tangentRatio)),
					localOutTangent = parent.InverseTransformPoint(data[i - 1].position + data[i - 1].rotation * Vector3forward * (distance * 0.5f * tangentRatio)),
					timeSinceLevelLoad = data[i - 1].timeSinceLevelLoad,
					percentage = 0,
				};
				lastDistance = distance;
				float nextDistance = i < data.Count-1 ? (data[i].position - data[i + 1].position).magnitude : 0f;
				LinkedFragment to = new LinkedFragment
				{
					localPosition = parent.InverseTransformPoint(data[i].position),
					localRotation = Quaternion.Inverse(parent.rotation) * data[i].rotation,
					localInTangent = parent.InverseTransformPoint(data[i].position + data[i].rotation * Vector3back * (distance * 0.5f * tangentRatio)),
					localOutTangent = parent.InverseTransformPoint(data[i].position + data[i].rotation * Vector3forward * (nextDistance * 0.5f * tangentRatio)),
					timeSinceLevelLoad = data[i].timeSinceLevelLoad,
					percentage = 1,
					previous = from,
				};
				from.next = to;

				_CalcSampleByResolution(from, to, resolution, out Fragment[] fragments, out float length);
				totalDistance += length;
				Session session = new Session
				{
					anchorStartDistance = anchorStartDistance,
					length = length,
					fragments = fragments,
				};
				sessions.Add(session);
			}
			return new Baked(parent, sessions, totalDistance);
		}

		public struct PosRotateTime
        {
			public Vector3 position { get; }
			public Quaternion rotation { get; }
			public float timeSinceLevelLoad { get; }
			public PosRotateTime(Vector3 _position, Quaternion _rotation, float _timeSinceLevelLoad)
            {
				position = _position;
				rotation = _rotation;
				timeSinceLevelLoad = _timeSinceLevelLoad;
            }
		}

		[System.Serializable]
		public enum eBakeMode
        {
			Tangent,
			Rotation,
        }

		/// <summary>Bake bezier information into samples</summary>
		[System.Serializable]
		public class Baked
		{
			public Transform parent;
			public float totalDistance; // total length of this curve
			public eBakeMode m_BakeMode;
			public List<Session> sessions;
			public Baked(Transform parent, List<Session> sessions, float length)
			{
				this.parent = parent;
				this.sessions = sessions;
				this.totalDistance = length;
			}
		}
		[System.Serializable]
		public class Session
		{
			public float anchorStartDistance; // based on from Tp index
			public float length; // length
			public Fragment[] fragments;
		}

		[System.Serializable]
		public struct Fragment
		{
			/// <summary>length toward next fragment.</summary>
			public float length;
			public float timeSinceLevelLoad;
			public Quaternion localRotation;
			public Vector3 localPosition, localInTangent, localOutTangent;
			public Quaternion rotation(Transform parent) => parent.rotation * localRotation;
			public Vector3 position(Transform parent) => parent.TransformPoint(localPosition);
			public Vector3 InTangent(Transform parent) => parent.TransformPoint(localInTangent);
			public Vector3 OutTangent(Transform parent) => parent.TransformPoint(localOutTangent);

		}

		/// <summary>
		/// linked list - used for <see cref="Fragment"/> calculation.
		/// </summary>
		public class LinkedFragment
		{
			public LinkedFragment previous;
			public LinkedFragment next;
			public float percentage;
			public float timeSinceLevelLoad;
			public Quaternion localRotation;
			public Vector3 localPosition, localInTangent, localOutTangent;
		}

		/// <summary>
		/// Calculate the point sample based on giving 
		/// <see cref="LinkedFragment"/> to construct the linked list data within tolerance error.
		/// </summary>
		/// <param name="from_localPosition"></param>
		/// <param name="from_localInTangent"></param>
		/// <param name="from_localOutTangent"></param>
		/// <param name="to_localPosition"></param>
		/// <param name="to_localInTangent"></param>
		/// <param name="to_localOutTangent"></param>
		/// <param name="percentage"></param>
		/// <param name="tolerance"></param>
		/// <param name="fragments"></param>
		/// <param name="length"></param>
		public static void CalcSampleByTolerance(
			Vector3 from_localPosition, Vector3 from_localInTangent, Vector3 from_localOutTangent,
			Vector3 to_localPosition, Vector3 to_localInTangent, Vector3 to_localOutTangent,
			float percentage, float tolerance,
			out Fragment[] fragments, out float length)
		{
			LinkedFragment from = new LinkedFragment
			{
				localInTangent = from_localInTangent, // just for reference
				localPosition = from_localPosition,
				localOutTangent = from_localOutTangent,
				percentage = 0,
			};
			LinkedFragment to = new LinkedFragment
			{
				localInTangent = to_localInTangent,
				localPosition = to_localPosition,
				localOutTangent = to_localOutTangent, // just for reference
				percentage = 1,
				previous = from,
			};
			from.next = to;
			CalcSampleByTolerance(from, to, percentage, tolerance, out fragments, out length);
		}

		/// <summary>
		/// Calculate the point sample based on giving 
		/// <see cref="LinkedFragment"/> to construct the linked list data within tolerance error.
		/// </summary>
		/// <param name="start"></param>
		/// <param name="end"></param>
		/// <param name="percentage"></param>
		/// <param name="tolerance"></param>
		/// <param name="fragments"></param>
		/// <param name="length"></param>
		public static void CalcSampleByTolerance(LinkedFragment start, LinkedFragment end, float percentage,
			float tolerance, out Fragment[] fragments, out float length)
		{
			LinkedFragment from = start;
			LinkedFragment to = end;
			try
			{
				_CalcSampleByTolerance(from, to, start, end, percentage, tolerance);
			}
			catch (System.StackOverflowException e)
			{
				Debug.LogError(e);
			}
			finally
			{
				Queue<Fragment> fQueue = new Queue<Fragment>(50);
				LinkedFragment pt = from;
				length = 0f;
				while (pt != null)
				{
					pt.previous = null; // remove linking, wait for GC
					Fragment fragment = new Fragment
					{
						localInTangent = pt.localInTangent,
						localPosition = pt.localPosition,
						localOutTangent = pt.localOutTangent,
						localRotation = pt.localRotation,
						timeSinceLevelLoad = pt.timeSinceLevelLoad,
						// length = wait
					};

					// fragment length
					if (pt.next != null)
					{
						Vector3 v = pt.next.localPosition - pt.localPosition;
						fragment.length = length = v.magnitude;
					}
					fQueue.Enqueue(fragment);
					pt = pt.next;
				}
                // fragments = fQueue.ToArrayClear();
                fragments = new Fragment[fQueue.Count];
                int i = 0;
                while (fQueue.Count > 0)
                    fragments[i++] = fQueue.Dequeue();
                fQueue.Clear();
				fQueue = null;
				from = null;
				to = null;
			}
		}

		/// <summary>
		/// Internal recursive function for
		/// <see cref="CalcSampleByTolerance(LinkedFragment, LinkedFragment, float, float, out Fragment[], out float)"/>
		/// </summary>
		private static void _CalcSampleByTolerance(LinkedFragment from, LinkedFragment to,
			LinkedFragment start, LinkedFragment end, float percentage,
			float tolerance)
		{
			if (from.next != to || to.previous != from)
				throw new UnityException("Logic error.");

			Vector3 lhs = from.localPosition;
			Vector3 rhs = to.localPosition;
			Vector3 rayVector = rhs - lhs;
			if (rayVector.sqrMagnitude <= tolerance * tolerance)
				return;
			Vector3 normalize = rayVector.normalized;

			Vector3 middlePoint = Bezier.Lerp(start.localPosition, start.localOutTangent, end.localInTangent, end.localPosition, percentage);
			float onRayDistance = Vector3.Dot(middlePoint - lhs, normalize);
			Vector3 pointBetweenFromTo = lhs + normalize * onRayDistance;

			Vector3 perpendicularVector = middlePoint - pointBetweenFromTo;
			float deviation = perpendicularVector.magnitude;
			if (deviation >= tolerance)
			{
				// Continue split.
				Bezier.LocateSplitTangentPoint(
					start.localPosition, start.localOutTangent,
					end.localInTangent, end.localPosition, percentage,
					out Vector3 splitPosition,
					out Vector3 splitInTangent,
					out Vector3 splitOutTangent);

				// Insert into linked list.
				LinkedFragment mid = new LinkedFragment()
				{
					localPosition = splitPosition,
					localInTangent = splitInTangent,
					localOutTangent = splitOutTangent,
					localRotation = Quaternion.Slerp(start.localRotation, end.localRotation, 0.5f),
					percentage = percentage,
					previous = from,
					next = to,
				};
				from.next = mid;
				to.previous = mid;


				float pt = Mathf.Lerp(from.percentage, percentage, 0.5f);
				_CalcSampleByTolerance(from, mid, start, end, pt, tolerance); // Left side

				pt = Mathf.Lerp(percentage, to.percentage, 0.5f);
				_CalcSampleByTolerance(mid, to, start, end, pt, tolerance); // right side
			}
		}

		private static void _CalcSampleByResolution(LinkedFragment start, LinkedFragment end, int resolution,
			out Fragment[] fragments, out float length)
        {
			length = 0f;
			Vector3 lhs = start.localPosition;
			Vector3 rhs = end.localPosition;
			Vector3 rayVector = rhs - lhs;
			if (rayVector.sqrMagnitude <= float.Epsilon)
			{
				fragments = new Fragment[0];
				return;
			}

			fragments = new Fragment[resolution];
			for (int i = 0; i < resolution; i++)
			{
				float pt = (float)i / resolution;
				Bezier.LocateSplitTangentPoint(start.localPosition, start.localOutTangent, end.localInTangent, end.localPosition, pt,
					out Vector3 splitPosition,
					out Vector3 splitInTangent,
					out Vector3 splitOutTangent);
				fragments[i] = new Fragment
				{
					localPosition = splitPosition,
					localInTangent = splitInTangent,
					localOutTangent = splitOutTangent,
					localRotation = Quaternion.Slerp(start.localRotation, end.localRotation, 0.5f),
					timeSinceLevelLoad = Mathf.Lerp(start.timeSinceLevelLoad, end.timeSinceLevelLoad, pt),
					// length = // wait
				};
				if (i > 0 && i < resolution - 1)
				{
					float len = (fragments[i - 1].localPosition - splitPosition).magnitude;
					fragments[i - 1].length = len;
					length += len;
				}
			}
		}
		#endregion Curve Sampling

		#region Mesh
		/// <summary>
		/// A cheat way to provide a EMPTY mesh without destroy mesh
		/// and signs with the normal vector.
		/// </summary>
		/// <param name="mesh"></param>
		private static void ClearMesh(ref Mesh mesh)
        {
			const string s_Empty = "Empty";
			if (mesh.normals.Length == 3 &&
				mesh.name == s_Empty)
				return;
			mesh.Clear();
			mesh.name = s_Empty;
			mesh.vertices = new Vector3[] { Vector3.zero, new Vector3(0f, 0.001f, 0f), new Vector3(0.001f, 0.001f, 0f) };
			mesh.uv = new Vector2[3] { Vector2.zero, Vector2.zero, Vector2.zero };
			mesh.triangles = new int[3] { 0, 1, 2 };
			mesh.normals = new Vector3[3] { Vector3.zero, Vector3.zero, Vector3.zero };
			mesh.tangents = new Vector4[3] { Vector4.zero, Vector4.zero, Vector4.zero };
			// mesh.RecalculateNormals();
		}

		/// <summary>Generate mesh for bezier curve</summary>
		/// <param name="_name"></param>
		/// <param name="partitions">the partitions for mesh width size distribution</param>
		/// <param name="samples">The baked curve result from
		/// <see cref="Bezier.BakeCurveByTolerance(Transform, IList{TangentPoint}, float)"/></param>
		/// <param name="mesh">The output mesh.</param>
		/// <param name="pathShape">to maintain the shape of path</param>
		public static void GenerateCurveMesh(string _name,
			float[] partitions,
			Bezier.Baked samples,
			AnimationCurve pathShape,
			ref Mesh mesh)
		{
			if (samples.sessions.Count == 0)
			{
				Debug.LogWarning($"Fail to {nameof(GenerateCurveMesh)} due to no sample.");
				ClearMesh(ref mesh);
				return;
			}

			if (partitions.Length == 0)
				partitions = new float[1] { 1f };
			
			// Notes : xSize based on partitions -> column
			int xSize = partitions.Length;
			float totalWidth = 0f;
			for (int i = 0; i < partitions.Length; i++)
				totalWidth += partitions[i];
			float halfWidth = totalWidth * 0.5f;

			// optimization Fetch memory size required
			int memSize = 0;
			foreach (var s in samples.sessions)
				memSize += s.fragments.Length;


			List<Fragment> curve = new List<Fragment>(memSize);
			List<float> pathLength = new List<float>(memSize);
			float accumuleLength = 0f;
            for (int j = 0; j < samples.sessions.Count; j++)
			{
                Session s = samples.sessions[j];
                curve.AddRange(s.fragments);
                for (int i = 0; i < s.fragments.Length; i++)
				{
                    accumuleLength += s.fragments[i].length;
					pathLength.Add(accumuleLength);
				}
			}

			// Notes : ySize are depend on Curve total anchor points.
			int ySize = curve.Count;
			if (ySize == 0)
			{
				Debug.LogWarning($"Fail to {nameof(GenerateCurveMesh)} due to ZERO session fragment info to construct.");
				ClearMesh(ref mesh);
				return;
			}
			float pathLengthTotal = samples.totalDistance;
			if (pathLengthTotal < float.Epsilon)
            {
				ClearMesh(ref mesh);
				return;
			}

			// Calculate all vertex in this row (y-axis)
			Vector3[] vertices = new Vector3[(xSize + 1) * (ySize + 1)];
			Vector2[] uv = new Vector2[vertices.Length];
			Vector4[] tangents = new Vector4[vertices.Length];
			Color[] colors = new Color[vertices.Length];
			for (int i = 0, y = 0; y <= ySize; y++)
            {
                // Convert into tangent point naming.
                bool endRow = y == ySize;
				int index = endRow ? y - 1 : y;
                Vector3 pivot = curve[index].position(samples.parent);
                Vector3 outTangent = curve[index].OutTangent(samples.parent);
                Vector3 inTangent = curve[index].InTangent(samples.parent);
				Vector3 virtualLeft = curve[index].rotation(samples.parent) * Vector3.right;
                float time = curve[index].timeSinceLevelLoad;
				float pathPt = GetPathPercentage(pathLength, ySize, pathLengthTotal, y);
				float scaleWidth = pathShape.Evaluate(pathPt);
				float columeWidth = 0f;

				// Calculate virtual Right for current path session.
				//DebugExtend.DrawLine(pivot, outTangent, Color.cyan, duration: 0.1f);
				//DebugExtend.DrawRay(pivot, virtualLeft, Color.red, 0.1f);
				//DebugExtend.DrawRay(pivot, outTangent, Color.blue, 0f);

				

                
                for (int x = 0; x <= xSize; x++, i++)
                {
                    // Reason for "x <= xSize",
                    // 3 Colume := { 0.2, 0.8, 0.2 }
                    // need 4 vertex { 0, 0.2, 1, 1.2 }
                    bool endColume = x == xSize;
                    Vector3 adjustVector = virtualLeft * ((columeWidth - halfWidth) * scaleWidth);
                    vertices[i] = pivot + adjustVector;

                    uv[i] = new Vector2((float)x / xSize, (float)y / ySize);
                    tangents[i] = Vector3.Cross(outTangent, virtualLeft);

					// extra info
					// xyz = virtualLeft
					// w = spawn time.
					if (columeWidth < halfWidth)
						colors[i] = new Color(-virtualLeft.x, -virtualLeft.y, -virtualLeft.z, time);
					else
						colors[i] = new Color(virtualLeft.x, virtualLeft.y, virtualLeft.z, time);

					if (!endColume)
					{
						columeWidth += partitions[x];
					}
					//if (i > 0) DebugExtend.DrawLine(vertices[i], vertices[i - 1], magenta);
					//if (i > 0) DebugExtend.DrawRay(vertices[i], tangents[i], Color.red);
				}
            }

            int[] triangles = new int[xSize * ySize * 6];
			for (int ti = 0, vi = 0, y = 0; y < ySize; y++, vi++)
			{
				for (int x = 0; x < xSize; x++, ti += 6, vi++)
				{
					triangles[ti] = vi;
					triangles[ti + 3] = triangles[ti + 2] = vi + 1;
					triangles[ti + 4] = triangles[ti + 1] = vi + xSize + 1;
					triangles[ti + 5] = vi + xSize + 2;
				}
			}
			curve = null;
			mesh = new Mesh
			{
				name = _name,
				vertices = vertices,
				uv = uv,
				colors = colors,
				triangles = triangles,
				tangents = tangents,
			};
			mesh.RecalculateNormals();
			// mesh.RecalculateTangents();
		}

        private static float GetPathPercentage(List<float> pathLength, int ySize, float pathLengthTotal, int y)
        {
            float pathPt = 0f;
            if (y < ySize)
            {
                if (pathLengthTotal > 0f) // avoid divide zero
                    pathPt = Mathf.Clamp01(pathLength[y] / pathLengthTotal);
            }
            else
            {
                pathPt = 1f;
            }

            return pathPt;
        }
        #endregion Mesh
    }
}