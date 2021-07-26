using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Projectile : MonoBehaviour
{
    //projectile attributes
    public float speed = 50;
    public bool hitScan = false;
    public float damage = 40;
    public float lifetime = 5;
    public float fireRate = 0.1f;
    public float terrainDamage = 0.01f;
    public bool resting = false;
    public GameObject aftermath;

    //individual attributes
    protected Vector3 momentum = Vector3.zero;
    protected Rigidbody rigidbody;
    protected float activeTime = 0;
    public int team = 0;

    protected Manager manager;

    virtual protected void Awake()
    {
        rigidbody = GetComponent<Rigidbody>();
        manager = GameObject.FindGameObjectWithTag("GameController").GetComponent<Manager>();
    }

    // Update is called once per frame
    virtual protected void FixedUpdate()
    {
        if (!resting)
        {
            if (manager.GetDistanceFromPlanets(transform.position) <= 0)
            {
                HitPlanet();
            }

            activeTime += Time.deltaTime;
            if (activeTime >= lifetime) SetResting(true);
        }
    }

    virtual public void SetProperties(Vector3 addedMomentum, int myTeam)
    {
        rigidbody.velocity = transform.forward * speed + addedMomentum;
        momentum = addedMomentum;
        team = myTeam;
    }

    virtual protected void HitPlanet()
    {
        Planet close = manager.GetClosestPlanet(transform.position);
        close.Terraform(transform.position, 0, terrainDamage);
        transform.position = close.ClosestContact(transform.position);
        SetResting(true);
    }

    virtual public void SetResting(bool state)
    {
        resting = state;
        if (resting)
        {
            if (aftermath) GameObject.Instantiate(aftermath, transform.position, transform.rotation);
            GameObject.Destroy(gameObject);
        }
    }

    virtual public float GetRange()
    {
        return speed * lifetime;
    }

    virtual protected void OnTriggerEnter(Collider other)
    {
        if (!resting)
        {
            //if collision is with an enemy, tell it about the hit
            Entity entity = other.gameObject.GetComponent<Entity>();
            if (!entity)
            {
                transform.position = other.ClosestPoint(transform.position);
                SetResting(true);
            }
            else if (entity.team != team)
            {
                transform.position = other.ClosestPoint(transform.position);
                entity.Attack(team, damage, transform.position);
                SetResting(true);
            }
        }
    }
}
