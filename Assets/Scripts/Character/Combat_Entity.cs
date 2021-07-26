using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Combat_Entity : Entity
{
    protected Manager manager;

    protected override void Start()
    {
        base.Start();
        manager = GameObject.FindGameObjectWithTag("GameController").GetComponent<Manager>();
        manager.AddToTargetList(gameObject);
    }

    protected override void Death()
    {
        manager.RemoveFromTargetList(gameObject);
        base.Death();
    }
}
