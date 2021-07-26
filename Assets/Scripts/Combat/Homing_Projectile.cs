using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Homing_Projectile : Projectile
{
    public bool smartHoming = true;
    public float turnSpeed = 50;
    Entity target;

    public override void SetProperties(Vector3 addedMomentum, int myTeam)
    {
        base.SetProperties(addedMomentum, myTeam);
        rigidbody.velocity = Vector3.zero;
        LockOntoTarget();
    }

    private void LockOntoTarget()
    {
        HashSet<GameObject> allTargets = manager.GetAllTargets();
        float bestTarget = -2;
        foreach (GameObject g in allTargets)
        {
            Entity entity = g.GetComponent<Entity>();
            if (entity.team != team)
            {
                Vector3 targetPos = entity.transform.position;
                float targetDot = Vector3.Dot(transform.forward, Vector3.Normalize(targetPos - transform.position));
                if (targetDot > bestTarget)
                {
                    bestTarget = targetDot;
                    target = entity;
                }
            }
        }
    }

    protected override void FixedUpdate()
    {
        base.FixedUpdate();
        float speedMult = 0.5f;
        //use a basic estimate to aim at where the target will be
        if (target)
        {
            Vector3 targetPos = target.transform.position;
            if (smartHoming)
            {
                float timeToHit = Vector3.Distance(transform.position, targetPos) / speed;
                targetPos += (target.GetMomentum() - momentum) * timeToHit;
            }
            //turn towards target
            Quaternion targetDir = Quaternion.LookRotation(targetPos - transform.position);
            rigidbody.MoveRotation(Quaternion.RotateTowards(transform.rotation, targetDir, Time.deltaTime * turnSpeed));

            float targetDot = Vector3.Dot(transform.forward, Vector3.Normalize(targetPos - transform.position));
            speedMult = Mathf.Clamp(targetDot, 0.5f, 1);
        }

        //move forwards
        rigidbody.MovePosition(transform.position + (transform.forward * speed * speedMult + momentum) * Time.deltaTime);
    }
}
