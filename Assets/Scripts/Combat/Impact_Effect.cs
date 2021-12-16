using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Impact_Effect : MonoBehaviour
{
    public float lifetime = 1;

    float timeAlive = 0;

    // Update is called once per frame
    void FixedUpdate()
    {
        timeAlive += Time.deltaTime;
        if (timeAlive > lifetime)
        {
            GameObject.Destroy(gameObject);
        }
    }
}
