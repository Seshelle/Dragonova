using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Impact_Effect : MonoBehaviour
{
    public float lifetime = 1;

    float timeAlive = 0;

    private void Start()
    {
        transform.localScale = Vector3.zero;
    }

    // Update is called once per frame
    void FixedUpdate()
    {
        timeAlive += Time.deltaTime;
        float lifeRatio = timeAlive / lifetime;
        transform.localScale = Vector3.one * (1 - Mathf.Abs(lifeRatio - 0.5f) * 2);
        if (timeAlive > lifetime)
        {
            GameObject.Destroy(transform.parent.gameObject);
        }
    }
}
