using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Power_Pipe : Structure
{
    public Transform connector;
    public Collider wireCollision;

    bool connecting = false;
    bool powered = false;
    float powerDistance = -1;
    float baseDistance = 0;
    Transform connectedTo = null;

    public override bool Place()
    {
        if (connecting) wireCollision.enabled = true;
        connecting = false;
        return base.Place();
    }

    private void OnTriggerEnter(Collider other)
    {
        if (!placed && !connecting && other.gameObject.CompareTag("Power"))
        {
            connecting = true;
            connectedTo = other.transform;
            if (other.gameObject.GetComponent<Power_Pipe>())
                baseDistance = other.gameObject.GetComponent<Power_Pipe>().GetPowerDistance();
        }
    }

    public float GetPowerDistance()
    {
        return powerDistance;
    }

    private void LateUpdate()
    {
        if (connecting)
        {
            connector.LookAt(connectedTo.transform);
            float distance = Vector3.Distance(connector.position, connectedTo.position);
            powerDistance = distance + baseDistance;
            print(powerDistance);
            connector.localScale = new Vector3(1, 1, distance);
        }
    }
}
