using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Shield : MonoBehaviour
{
    public float radius = 0.5f;

    bool dirty = false;

    Material material;
    // Start is called before the first frame update
    void Start()
    {
        material = GetComponent<Renderer>().material;
    }

    public void HitShield(Vector3 hitFrom)
    {
        dirty = true;
        hitFrom -= transform.position;
        Vector4 hit = new Vector4(hitFrom.x, hitFrom.y, hitFrom.z, Time.timeSinceLevelLoad);
        material.SetVector("_HitNormal", hit);
    }

    private void OnDestroy()
    {
        //When materials are edited they become a copy
        //Those materials must be destroyed to prevent polluting memory
        if (dirty) Destroy(material);
    }
}
