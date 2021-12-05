using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Structure : MonoBehaviour
{
    Planet_Manager manager;

    // Start is called before the first frame update
    void Start()
    {
        manager = GameObject.FindGameObjectWithTag("GameController").GetComponent<Planet_Manager>();
    }

    virtual public bool Place()
    {
        transform.parent = manager.GetClosestPlanet(transform.position).transform;
        return true;
    }
}
