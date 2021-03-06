using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Enemy : Combat_Entity
{
    public float speed = 10;
    public float turnSpeed = 0.5f;
    public float attackTime = 10;
    public float maneuverTime = 2;
    public Projectile projectile;

    float currentCooldown = 0;
    float projSpeed = 0;
    float projRange;
    float fireCooldown = 1;
    bool hitScan;

    bool attacking = true;
    float timeInMode = 0;
    bool retreat = false;

    Player target;
    Vector3 targetPos;
    Rigidbody rigidbody;
    float moveMult = 1;

    // Start is called before the first frame update
    protected override void Start()
    {
        base.Start();
        rigidbody = GetComponent<Rigidbody>();
        target = GameObject.FindGameObjectWithTag("Player").GetComponent<Player>();
        projSpeed = projectile.speed;
        projRange = projectile.GetRange();
        fireCooldown = projectile.fireRate;
        hitScan = projectile.hitScan;
        timeInMode = Random.value * attackTime;
    }

    private void FixedUpdate()
    {
        FindTarget();
        MoveToTarget();
        TakeAction();
    }

    protected virtual void FindTarget()
    {
        timeInMode += Time.deltaTime;
        if (timeInMode >= 0) ChangeModes();

        if (attacking)
        {
            retreat = false;
            if (hitScan)
            {
                targetPos = target.transform.position;
            }
            else
            {
                //get where to aim at through prediction
                Vector3 relativeVel = target.GetMomentum() - transform.forward * speed;
                Vector3 relativePos = target.transform.position - transform.position;
                //(q + ax)^2 etc.. - (sx)^2 = 0

                //find close enough approximation for zeroes of the function
                //zero means the shot will hit at specified time
                float timeToHit = 0;
                const float epsilon = 0.1f;
                float stepSize = 1f;
                float prevSolution = Mathf.Pow(relativePos.x + relativeVel.x * timeToHit, 2);
                prevSolution += Mathf.Pow(relativePos.y + relativeVel.y * timeToHit, 2);
                prevSolution += Mathf.Pow(relativePos.z + relativeVel.z * timeToHit, 2);
                prevSolution -= Mathf.Pow(projSpeed * timeToHit, 2);

                for (int i = 0; i < 10; i++)
                {
                    timeToHit += stepSize;
                    //see what the function resolves to
                    float solution = Mathf.Pow(relativePos.x + relativeVel.x * timeToHit, 2);
                    solution += Mathf.Pow(relativePos.y + relativeVel.y * timeToHit, 2);
                    solution += Mathf.Pow(relativePos.z + relativeVel.z * timeToHit, 2);
                    solution = Mathf.Sqrt(solution) - projSpeed * timeToHit;

                    //if the function resolves to near zero, we have found our time to hit
                    if (Mathf.Abs(solution) <= epsilon) break;

                    //if the solution passed over 0 move backwards by a half step
                    if (Mathf.Sign(solution) != Mathf.Sign(prevSolution)) stepSize *= -0.5f;
                    prevSolution = solution;
                }

                targetPos = target.transform.position + target.GetMomentum() * timeToHit;
            }
        }
        else
        {
            //move away from each other
            retreat = true;
            Vector3 closeAlly = manager.ClosestTarget(transform.position).transform.position;
            targetPos = closeAlly;
        }

        if (manager.GetDistanceFromPlanets(transform.position) < 300)
        {
            //avoid planet
            if (attacking) ChangeModes();
            retreat = true;
            targetPos = manager.GetClosestPlanet(transform.position).transform.position;
        }
    }

    protected virtual void ChangeModes()
    {
        if (attacking) timeInMode = -maneuverTime;
        else timeInMode = -attackTime;
        attacking = !attacking;
    }

    protected virtual void MoveToTarget()
    {
        //turn towards target
        Quaternion targetDir;
        if (retreat) targetDir = Quaternion.LookRotation(transform.position - targetPos);
        else targetDir = Quaternion.LookRotation(targetPos - transform.position);

        //move forwards
        rigidbody.rotation = Quaternion.RotateTowards(transform.rotation, targetDir, Time.deltaTime * turnSpeed);
        rigidbody.MovePosition(transform.position + transform.forward * speed * Time.deltaTime);
    }

    protected virtual void TakeAction()
    {
        currentCooldown += Time.deltaTime;
        if (attacking)
        {
            //fire projectile when player is in sights and in range
            if (currentCooldown >= fireCooldown)
            {
                currentCooldown = 0;
                if (Vector3.Distance(transform.position, targetPos) <= projRange
                    && Vector3.Dot(transform.forward.normalized, (transform.position - targetPos).normalized) < -0.9f)
                {
                    Vector3 spawnPoint = transform.position + transform.forward;
                    GameObject newProj = GameObject.Instantiate(projectile.gameObject, spawnPoint, transform.rotation);
                    Projectile projComponent = newProj.GetComponent<Projectile>();
                    projComponent.SetProperties(GetMomentum(), team);
                }
            }
        }
    }

    public override Vector3 GetMomentum()
    {
        return transform.forward * speed;
    }
}
