using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Entity : MonoBehaviour
{
    public int team = 1;
    public float Maxhealth = 100;

    protected float health;

    protected Shield shield;

    // Start is called before the first frame update
    protected virtual void Start()
    {
        shield = GetComponentInChildren<Shield>();
        health = Maxhealth;
    }

    public void Attack(int fromTeam, float damage, Vector3 hitFrom)
    {
        if (fromTeam != team)
        {
            health -= damage;
            if (health <= 0)
            {
                Death();
            }
            else
            {
                shield.HitShield(hitFrom);
            }
        }
    }

    virtual protected void Death()
    {
        GameObject.Destroy(gameObject);
    }

    virtual public Vector3 GetMomentum()
    {
        return Vector3.zero;
    }

    public int GetHealthAsInt()
    {
        return Mathf.CeilToInt(health);
    }
}
