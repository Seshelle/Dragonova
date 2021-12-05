using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Dragon : MonoBehaviour
{
    public float slowSpeed = 50;
    public float boostSpeed = 100;
    public float maxBoostTime = 2;
    public float maxSpeed = 200;
    public float deceleration = 20;
    public float turningSpeed = 1.0f;
    public float followAltitude = 50;

    Player player;
    Planet_Manager manager;
    Rigidbody rigidbody;
    float moveSpeed = 5;
    Vector3 rotVec;
    Vector3 moveDirection = Vector3.zero;
    bool isMounted = true;
    float timeSinceBoost = 0;

    private void Start()
    {
        rigidbody = GetComponent<Rigidbody>();
        player = GameObject.FindGameObjectWithTag("Player").GetComponent<Player>();
        manager = GameObject.FindGameObjectWithTag("GameController").GetComponent<Planet_Manager>();
    }

    // Update is called once per frame
    void Update()
    {
        if (isMounted)
        {
            float driftTurn = 2;
            float decelerateAmount = deceleration;
            if (Input.GetButton("Sprint"))
            {
                //charge up a boost
                timeSinceBoost += Time.deltaTime;
                decelerateAmount *= 2;
                moveDirection = Vector3.RotateTowards(moveDirection, transform.forward, Time.deltaTime / 4, 0);
                if (timeSinceBoost > maxBoostTime) timeSinceBoost = maxBoostTime;
            }
            else
            {
                moveDirection = transform.forward;
                driftTurn = 1;
                moveSpeed += timeSinceBoost * (boostSpeed / maxBoostTime);
                timeSinceBoost = 0;
            }

            if (moveSpeed > maxSpeed) moveSpeed = maxSpeed;
            if (moveSpeed < 0) moveSpeed = 0;

            //speed decays toward default speed naturally
            if (moveSpeed > slowSpeed) moveSpeed -= Time.deltaTime * decelerateAmount;

            if (Input.GetButton("Grapple"))
            {
                moveSpeed -= Time.deltaTime * decelerateAmount * 4;
            }

            //turn with wasd
            rotVec = new Vector3(Input.GetAxis("Vertical"), Input.GetAxis("Horizontal"), Input.GetAxis("Roll"));
            Quaternion deltaRotation = Quaternion.Euler(rotVec * turningSpeed * driftTurn * Time.deltaTime);
            rigidbody.MoveRotation(rigidbody.rotation * deltaRotation);
        }
        else
        {
            moveDirection = transform.forward;
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
            rigidbody.MovePosition(rigidbody.position + moveDirection * moveSpeed * Time.deltaTime);
        }
    }

    public Vector3 GetMoveVector()
    {
        return transform.forward * moveSpeed;
    }

    public void SetMounted(bool state)
    {
        isMounted = state;
    }
}
