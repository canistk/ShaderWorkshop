using UnityEngine;
using System.Collections;
using System.Collections.Generic;

namespace Kit.MeshLib.Core
{
	public static class MeshExtend
	{
		
		/// <summary>
		/// <see cref="https://catlikecoding.com/unity/tutorials/procedural-grid/"/>
		/// </summary>
		/// <param name="_name"></param>
		/// <param name="xSize"></param>
		/// <param name="ySize"></param>
		/// <returns></returns>
		public static void GeneratePlane(string _name, int xSize, int ySize, out Mesh mesh)
        {
			Vector3[] vertices = new Vector3[(xSize + 1) * (ySize + 1)];
			Vector2[] uv = new Vector2[vertices.Length];
			Vector4[] tangents = new Vector4[vertices.Length];
			Vector4 tangent = new Vector4(1f, 0f, 0f, -1f);
			for (int i = 0, y = 0; y <= ySize; y++)
			{
				for (int x = 0; x <= xSize; x++, i++)
				{
					vertices[i] = new Vector3(x, y);
					uv[i] = new Vector2((float)x / xSize, (float)y / ySize);
					tangents[i] = tangent;
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

			mesh = new Mesh
			{
				name = _name,
				vertices = vertices,
				uv = uv,
				triangles = triangles,
				tangents = tangents,
			};
		}

		public static Mesh CreatePlaneXY(string _name, float _width, float _height)
		{
			List<Vector3> vertices = new List<Vector3>(10);
			List<Vector2> uv = new List<Vector2>(10);
			List<int> triangles = new List<int>(10);
			
			CalcPlaneXY(vertices, uv, triangles, _width, _height, Vector3.zero);
			// CalcPlaneXY(vertices, uv, triangles, _width, _height * 0.5f, new Vector3(0f, _height, 0f));

			Mesh _mesh = new Mesh
			{
				name = _name,
				vertices = vertices.ToArray(),
				uv = uv.ToArray(),
				triangles = triangles.ToArray(),
			};
			_mesh.RecalculateNormals();
			return _mesh;
		}

		public static void CalcPlaneXY(
			List<Vector3> vertices,
			List<Vector2> uv,
			List<int> triangles,
			float width, float height, Vector3 pivotOffset = default)
		{
			/*****
			1    3

			0    2
			//*****/
			// Vertices
			float _halfW = width * .5f;
			float _halfH = height * .5f;
			vertices.Add(pivotOffset + new Vector3(-_halfW, -_halfH, 0f)); // left-Bottom
			vertices.Add(pivotOffset + new Vector3(-_halfW, _halfH, 0f)); // left-Top
			vertices.Add(pivotOffset + new Vector3(_halfW, -_halfH, 0f)); // right-Bottom
			vertices.Add(pivotOffset + new Vector3(_halfW, _halfH, 0f)); // right-Top

			// UV
            uv.Add(new Vector2(0, 0)); // left-bottom
			uv.Add(new Vector2(0, 1)); // left-top
            uv.Add(new Vector2(1, 0)); // right-bottom
            uv.Add(new Vector2(1, 1)); // right-top

			// Triangles
			// 0,1,2
			int startIndex = triangles.Count;
			triangles.Add(startIndex + 0);
			triangles.Add(startIndex + 1);
			triangles.Add(startIndex + 2);

			// 2,1,3
			triangles.Add(startIndex + 2);
			triangles.Add(startIndex + 1);
			triangles.Add(startIndex + 3);
		}

		/// <summary>Left hand system,
		/// assume a clockwise order vertex, generate a normal vector for this surface.
		/// </summary>
		/// <param name="v0"></param>
		/// <param name="v1"></param>
		/// <param name="v2"></param>
		/// <returns></returns>
		internal static Vector3 GetLeftHandFaceNormal(Vector3 v0, Vector3 v1, Vector3 v2) => Vector3.Cross(v2 - v1, v0 - v1).normalized;

		public static Mesh Clone(this Mesh mesh)
        {
            var copy = new Mesh();
            foreach(var property in typeof(Mesh).GetProperties())
            {
                if(property.GetSetMethod() != null && property.GetGetMethod() != null)
                {
                    property.SetValue(copy, property.GetValue(mesh, null), null);
                }
            }
            return copy;
        }


		/// <summary>Find out the point nearests, based on the vertex.
		/// <see cref="http://answers.unity3d.com/questions/7788/closest-point-on-mesh-collider.html"/> 
		/// </summary>
		/// <returns>The cloeset vertex to point.</returns>
		/// <param name="point">Point.</param>
		public static Vector3 ClosestVertexOnMeshTo(this MeshFilter meshFilter, Vector3 point)
		{
			// convert point to local space
			point = meshFilter.transform.InverseTransformPoint(point);
			float minDistanceSqr = Mathf.Infinity;
			Vector3 nearestVertex = Vector3.zero;
			// scan all vertices to find nearest
			foreach (Vector3 vertex in meshFilter.mesh.vertices)
			{
				Vector3 diff = point-vertex;
				float distSqr = diff.sqrMagnitude;
				if (distSqr < minDistanceSqr)
				{
					minDistanceSqr = distSqr;
					nearestVertex = vertex;
				}
			}
			// convert nearest vertex back to world space
			return meshFilter.transform.TransformPoint(nearestVertex);
		}

		public static Mesh ReGenMesh(Mesh mesh, int groupCount)
		{
			if (mesh == null)
				throw new System.NullReferenceException();

			var vertices = mesh.vertices;
			var uv = mesh.uv;
			var triangles = mesh.triangles;

			var newTriangles = new int[triangles.Length];
			var newVertices = new Vector3[triangles.Length];
			var newUv = new Vector2[triangles.Length];
			var newUv2 = new Vector2[triangles.Length];
			var newUv3 = new Vector2[triangles.Length];

			var triCount = triangles.Length / 3;
			var triCenters = new Vector3[triCount];

			var groupId = new float[triCount];

			for (int i = 0; i < triCount; i++)
			{
				var v0 = vertices[triangles[i * 3]];
				var v1 = vertices[triangles[i * 3 + 1]];
				var v2 = vertices[triangles[i * 3 + 2]];

				triCenters[i] = (v0 + v1 + v2) / 3;
				groupId[i] = (float)Random.Range(0, groupCount) / groupCount;
			}

			for (int i = 0; i < triangles.Length; i++)
			{
				var vi = triangles[i];
				newTriangles[i] = i;
				newVertices[i] = vertices[vi];
				newUv[i] = uv[vi];

				var tri = i / 3;
				var center = triCenters[tri];
				newUv2[i] = new Vector2(center.x, center.y);
				newUv3[i] = new Vector2(center.z, groupId[tri]);
			}

			var newMesh = new Mesh();
			newMesh.name = "NewMesh";
			newMesh.vertices = newVertices;
			newMesh.uv = newUv;
			newMesh.uv2 = newUv2;
			newMesh.uv3 = newUv3;
			newMesh.triangles = newTriangles;
			return newMesh;
		}
	}
}