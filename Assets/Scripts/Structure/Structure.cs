using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Structure : MonoBehaviour
{
    protected Planet_Manager manager;
    protected bool placed = false;

    // Start is called before the first frame update
    void Awake()
    {
        manager = GameObject.FindGameObjectWithTag("GameController").GetComponent<Planet_Manager>();
    }

    virtual public bool Place()
    {
        placed = true;
        transform.parent = manager.GetClosestPlanet(transform.position).transform;
        return true;
    }
}
