using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Shadow_Cam : MonoBehaviour
{
    public GameObject mainCam;
    Transform camTransform;
    Renderer myRenderer;

    private void Awake()
    {
        camTransform = mainCam.transform;
        myRenderer = GetComponent<Renderer>();
    }

    // Update is called once per frame
    void LateUpdate()
    {
        Vector3 round = new Vector3(transform.position.x, camTransform.position.y, camTransform.position.z);
        //round.y = Mathf.Round(round.y);
        //round.z = Mathf.Round(round.z);
        transform.SetPositionAndRotation(round, transform.rotation);
    }

    public void SetTextures(Cubemap cube, float rotationSpeed)
    {
        myRenderer.material.SetTexture("_MainTex", cube);
        myRenderer.material.SetFloat("_RotationSpeed", rotationSpeed);
    }
}
