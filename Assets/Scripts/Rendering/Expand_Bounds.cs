using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Expand_Bounds : MonoBehaviour
{
    public bool expand = false;

    void FixedUpdate()
    {
        if (expand)
        {
            expand = false;
            MeshFilter mesh = GetComponent<MeshFilter>();
            mesh.sharedMesh.bounds = new Bounds(Vector3.zero, Vector3.one * 100000);
            //mesh.sharedMesh.RecalculateBounds();
        }
    }
}
