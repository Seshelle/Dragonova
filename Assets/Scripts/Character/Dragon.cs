using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Dragon : MonoBehaviour
{
    public float slowSpeed = 50;
    public float boostSpeed = 100;
    public float maxSpeed = 200;
    public float deceleration = 20;
    public float boostCooldown = 2;
    public float turningSpeed = 1.0f;
    public float followAltitude = 50;
    public CapsuleCollider collider;

    Player player;
    Manager manager;
    Rigidbody rigidbody;
    float moveSpeed = 50;
    Vector3 rotVec;
    bool isMounted = true;
    float timeSinceBoost = 1000;

    private void Start()
    {
        rigidbody = GetComponent<Rigidbody>();
        player = GameObject.FindGameObjectWithTag("Player").GetComponent<Player>();
        manager = GameObject.FindGameObjectWithTag("GameController").GetComponent<Manager>();
    }

    // Update is called once per frame
    void Update()
    {
        if (isMounted)
        {
            //speed decays toward default speed naturally
            if (moveSpeed > slowSpeed)
            {
                moveSpeed -= Time.deltaTime * deceleration;
            }

            if (Input.GetButton("Grapple"))
            {
                moveSpeed -= Time.deltaTime * deceleration * 3;
            }

            timeSinceBoost += Time.deltaTime;
            if (timeSinceBoost >= boostCooldown && Input.GetButton("Sprint"))
            {
                //boost forward
                timeSinceBoost = 0;
                moveSpeed += boostSpeed;
            }

            if (moveSpeed > maxSpeed) moveSpeed = maxSpeed;
            if (moveSpeed < 0) moveSpeed = 0;

            //turn with wasd
            rotVec = new Vector3(Input.GetAxis("Vertical"), Input.GetAxis("Horizontal"), Input.GetAxis("Roll"));
            Quaternion deltaRotation = Quaternion.Euler(rotVec * turningSpeed * Time.deltaTime);
            rigidbody.MoveRotation(rigidbody.rotation * deltaRotation);
        }
    }

    private void FixedUpdate()
    {
        if (isMounted)
        {
            //transform.Rotate(rotVec * turningSpeed * Time.deltaTime);
            //Quaternion deltaRotation = Quaternion.Euler(rotVec * turningSpeed * Time.deltaTime);
            //rigidbody.MoveRotation(rigidbody.rotation * deltaRotation);
        }
        else
        {
            //turn towards player
            Vector3 origin = Vector3.zero;
            Vector3 target = player.transform.position;
            target += Vector3.Normalize(target - origin) * followAltitude;

            Quaternion targetDir = Quaternion.LookRotation(target - transform.position, player.transform.up);
            Quaternion look = Quaternion.RotateTowards(transform.rotation, targetDir, turningSpeed * Time.deltaTime);
            rigidbody.MoveRotation(look);

            //if pointing away from the player, slow down
            //moveMultiplier = maxMoveMultiplier / 5;
            moveSpeed = Vector3.Dot(transform.forward, Vector3.Normalize(target - transform.position)) * maxSpeed;
            moveSpeed = Mathf.Max(2, moveSpeed);
        }

        //check if front or back of dragon is intersecting a planet
        Planet closest = manager.GetClosestPlanet(transform.position);
        Vector3 front = transform.position + transform.forward * 5;
        Vector3 direction = closest.transform.position - front;
        float aboveSurface = Vector3.Magnitude(direction) - closest.GetPlanetHeight(-direction, 2);

        if (aboveSurface <= 0)
        {
            transform.Translate(direction.normalized * (aboveSurface - 0.01f), Space.World);
            moveSpeed = 0;
        }
        else
        {
            //transform.Translate(transform.forward * movementSpeed * Time.deltaTime * moveMultiplier, Space.World);
            rigidbody.MovePosition(rigidbody.position + transform.forward * moveSpeed * Time.deltaTime);
        }
    }

    public Vector3 GetMoveVector()
    {
        return transform.forward * moveSpeed;
    }

    public void SetMounted(bool state)
    {
        isMounted = state;
        collider.enabled = !isMounted;
    }
}
