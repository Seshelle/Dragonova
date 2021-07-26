using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Overlay_Controller : MonoBehaviour
{
    public Camera mainCam;

    // Start is called before the first frame update
    void Start()
    {
        mainCam = GameObject.FindGameObjectWithTag("MainCamera").GetComponent<Camera>();
    }

    // Update is called once per frame
    void Update()
    {
        transform.rotation = mainCam.transform.rotation;
    }
}
