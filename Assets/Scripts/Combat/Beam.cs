using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Beam : Projectile
{
    public float beamLength = 1000;
    LineRenderer line;

    protected override void Awake()
    {
        base.Awake();
        line = GetComponent<LineRenderer>();
    }

    public override void SetProperties(Vector3 addedMomentum, int myTeam)
    {
        base.SetProperties(addedMomentum, myTeam);
        line.SetPositions(new Vector3[] { transform.position, transform.position + transform.forward * beamLength });
        RaycastHit[] hits = Physics.RaycastAll(transform.position, transform.forward, beamLength);
        foreach (RaycastHit hit in hits)
        {
            Entity hitEntity = hit.collider.gameObject.GetComponent<Entity>();
            if (hitEntity)
            {
                hitEntity.Attack(team, damage, transform.position);
            }
        }
    }

    public override float GetRange()
    {
        return beamLength;
    }

    private void Update()
    {
        line.SetPositions(new Vector3[] { transform.position, transform.position + transform.forward * beamLength });
    }

    protected override void FixedUpdate()
    {
        activeTime += Time.deltaTime;
        if (activeTime >= lifetime) SetResting(true);
    }
}
