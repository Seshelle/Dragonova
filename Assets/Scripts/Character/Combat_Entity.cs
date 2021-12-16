using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Combat_Entity : Entity
{
    protected Planet_Manager manager;

    protected override void Start()
    {
        base.Start();
        manager = GameObject.FindGameObjectWithTag("GameController").GetComponent<Planet_Manager>();
        manager.AddToTargetList(gameObject);
    }

    private void OnDestroy()
    {
        manager.RemoveFromTargetList(gameObject);
    }
}
