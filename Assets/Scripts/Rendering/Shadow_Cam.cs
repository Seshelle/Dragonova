using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Shadow_Cam : MonoBehaviour
{
    public GameObject mainCam;
    Transform camTransform;
    public Renderer[] renders;

    private void Start()
    {
        camTransform = mainCam.transform;
    }

    // Update is called once per frame
    void LateUpdate()
    {
        transform.SetPositionAndRotation(new Vector3(transform.position.x, camTransform.position.y, camTransform.position.z), transform.rotation);
    }

    public void SetTextures(Cubemap cube, float rotationSpeed)
    {
        foreach (Renderer r in renders)
        {
            r.material.SetTexture("_MainTex", cube);
            r.material.SetFloat("_RotationSpeed", rotationSpeed);
        }
    }
}
