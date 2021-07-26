using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Area_Damage : MonoBehaviour
{
    public float damage = 50;
    public float radius = 3;

    // Start is called before the first frame update
    void Start()
    {
        Collider[] hits = Physics.OverlapSphere(transform.position, radius);
        foreach (Collider hit in hits)
        {
            Entity hitEntity = hit.gameObject.GetComponent<Entity>();
            if (hitEntity)
            {
                hitEntity.Attack(-1, damage, transform.position);
            }
        }
    }
}
