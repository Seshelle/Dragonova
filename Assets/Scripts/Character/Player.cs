using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Player : Combat_Entity
{
    public Dragon dragon;
    public float sensitivity = 2.0f;
    public float maxAngle = 80.0f;
    public float walkSpeed = 40;
    public float sprintSpeedMod = 2;
    public float jumpSpeed = 4000;
    public float jumpForce = 10;
    public float gravForce = 30;
    public float height = 1;
    public Projectile projectile;
    //public float fireRate = 0.1f;
    public Grappling_Hook grapple;
    public GameObject structure;

    bool mounted = true;
    float regen = 5;
    float fireRate;
    float lastFire = 99;

    GameObject camera;
    Rigidbody rigidbody;

    bool jumpingUp = false;
    bool grounded = false;
    float snaprange = 0.5f;
    bool grappling = false;

    Vector3 prevPos;
    Vector3 momentum;

    GameObject heldItem;
    bool holdingItem = false;

    private void Awake()
    {
        Application.targetFrameRate = 60;
    }

    // Start is called before the first frame update
    protected override void Start()
    {
        base.Start();
        fireRate = projectile.fireRate;
        prevPos = transform.position;
        camera = GameObject.FindGameObjectWithTag("MainCamera");
        rigidbody = GetComponent<Rigidbody>();
    }

    // Update is called once per frame
    void Update()
    {
        //regenerate health
        health += regen * Time.deltaTime;
        if (health > Maxhealth) health = Maxhealth;

        if (!Manager.gamePaused)
        {
            //reduce sensitivity when looking at extreme up or down angle
            float difference = 20;
            float rotX = camera.transform.localRotation.eulerAngles.x;
            if (rotX > 180)
            {
                difference = rotX - (360 - maxAngle);
            }
            else
            {
                difference = maxAngle - rotX;
            }
            if (difference < 20)
            {
                difference = 20;
            }

            // get mouse input for camera rotation
            float y = Input.GetAxis("Mouse X") * (sensitivity / 2) * difference / (maxAngle / 2);
            float x = Input.GetAxis("Mouse Y") * sensitivity;
            camera.transform.Rotate(-x, y, 0);
            rotX = camera.transform.localRotation.eulerAngles.x;
            if (rotX > 180 && rotX < (360 - maxAngle))
            {
                rotX = (360 - maxAngle);
            }
            else if (rotX < 180 && rotX > maxAngle)
            {
                rotX = maxAngle;
            }
            camera.transform.localRotation = Quaternion.Euler(rotX, camera.transform.localRotation.eulerAngles.y, 0);

            //dismount dragon if riding dragon
            if (mounted && Input.GetButtonDown("Jump"))
            {
                SetMounted(false);
            }

            //fire gun
            lastFire += Time.deltaTime;
            if (lastFire >= fireRate && Input.GetButton("Fire1"))
            {
                lastFire = 0;
                Vector3 spawnPoint = transform.position + camera.transform.forward * 2 + camera.transform.right * 0.5f - camera.transform.up * 0.3f;
                GameObject newProj = GameObject.Instantiate(projectile.gameObject, spawnPoint, camera.transform.rotation);
                Projectile projComponent = newProj.GetComponent<Projectile>();
                projComponent.SetProperties(GetMomentum(), team);
            }

            //grapple
            if (!mounted && grapple.resting && Input.GetButtonDown("Grapple"))
            {
                grapple.SetResting(true);
                Vector3 spawnPoint = transform.position + camera.transform.forward * 2 + camera.transform.right * 0.5f - camera.transform.up * 0.3f;
                grapple.transform.position = spawnPoint;
                grapple.transform.rotation = camera.transform.rotation;
                grapple.SetProperties(GetMomentum(), team);
                grapple.StartGrapple();
            }

            //interact
            if (Input.GetButtonDown("Interact"))
            {
                if (Vector3.Distance(transform.position, dragon.transform.position) < 40)
                {
                    SetMounted(true);
                }
            }

            //build
            if (Input.GetButtonDown("Cycle"))
            {
                if (!holdingItem)
                {
                    holdingItem = true;
                    GameObject block = GameObject.Instantiate(structure, camera.transform);
                    block.transform.localPosition = Vector3.forward * 5;
                    heldItem = block;
                }
                else
                {
                    holdingItem = false;
                    heldItem.transform.parent = manager.GetClosestPlanet(transform.position).transform;
                }
            }
        }
    }

    private void FixedUpdate()
    {
        //get change in world coordinates as momentum
        momentum = (transform.position - prevPos) / Time.deltaTime;
        prevPos = transform.position;

        if (!mounted)
        {
            //get position of closest planet
            Planet closest = manager.GetClosestPlanet(transform.position);
            Vector3 direction = closest.transform.position - transform.position;
            Vector3 gravity = Vector3.Normalize(direction);
            //correct rotation by rotating transform to planet surface
            Quaternion correction = Quaternion.FromToRotation(-transform.up, gravity);
            transform.Rotate(correction.eulerAngles, Space.World);
            //rigidbody.MoveRotation(correction);

            //float height = closest.GetPlanetHeight(-direction);
            float elevation = closest.GetPlanetHeight(-direction, height);
            float aboveSurface = Vector3.Magnitude(direction) - elevation;

            if (aboveSurface - snaprange > 0)
            {
                grounded = false;
                if (!grappling) rigidbody.AddForce(gravity * gravForce, ForceMode.Acceleration);
                //remove jumping state when gravity takes over
                if (jumpingUp && Vector3.Dot(gravity, rigidbody.velocity) > 0)
                {
                    jumpingUp = false;
                }
            }
            else if (aboveSurface < snaprange && aboveSurface > 0)
            {
                //if player is very close to surface, snap them to surface.
                //disable snapping while jumping upwards
                if (!jumpingUp && !grappling)
                {
                    transform.Translate(aboveSurface * gravity, Space.World);
                    grounded = true;
                }
            }
            else
            {
                //move player out of the ground if they are penetrating it a lot
                transform.Translate(aboveSurface * gravity, Space.World);
                grounded = true;
                jumpingUp = false;
            }

            //locomotion
            Vector3 moveDir = new Vector3(Input.GetAxisRaw("Horizontal"), 0, 0);
            moveDir = camera.transform.TransformDirection(moveDir).normalized;
            Vector3 trueForward = Vector3.ProjectOnPlane(camera.transform.forward, transform.up);
            if (grappling)
            {
                moveDir += (Input.GetAxisRaw("Vertical") * transform.up).normalized;
            }
            else
            {
                moveDir += (Input.GetAxisRaw("Vertical") * trueForward).normalized;
            }
            float speedMod = 1;
            if (Input.GetButton("Sprint")) speedMod = sprintSpeedMod;
            Vector3 desiredVelocity = moveDir.normalized * speedMod;
            if (grounded)
            {
                //grappling = false;
                rigidbody.velocity = desiredVelocity * walkSpeed;
                //rigidbody.AddForce(desiredVelocity * walkSpeed, ForceMode.Acceleration);
                //if (!transform.parent) transform.parent = closest.transform;
            }
            else
            {
                rigidbody.drag = 0.1f;
                Vector3 jumpAcc = desiredVelocity * jumpSpeed;
                rigidbody.AddForce(jumpAcc, ForceMode.Acceleration);
            }

            //player can jump if grounded
            if (((grounded && !jumpingUp) || grappling)  && Input.GetButton("Jump"))
            {
                if (!grappling) rigidbody.AddForce(-gravity * jumpForce, ForceMode.VelocityChange);
                jumpingUp = true;
                grounded = false;
                grappling = false;
            }

        }
    }

    public void SetGrappling(bool grappleState)
    {
        grappling = grappleState;
        if(grappling)
        {
            if (Vector3.Dot(rigidbody.velocity.normalized, transform.up) < 0)
            {
                rigidbody.velocity = Vector3.ProjectOnPlane(rigidbody.velocity, transform.up);
            }
            if (grounded) transform.Translate(transform.up * snaprange * 1.5f, Space.World);
            //if (grounded) rigidbody.MovePosition(rigidbody.position + transform.up * snaprange * 1.5f);
        }
    }

    public void SetMounted(bool state)
    {
        mounted = state;
        rigidbody.isKinematic = state;
        SetGrappling(false);
        if (mounted)
        {
            transform.parent = dragon.transform;
            transform.localPosition = new Vector3(0, 2, 0);
            transform.localRotation = Quaternion.identity;
            rigidbody.velocity = Vector3.zero;
        }
        else
        {
            transform.parent = null;
            rigidbody.velocity = dragon.GetMoveVector();
        }
        dragon.SetMounted(state);
    }

    public bool IsGrappling()
    {
        return grappling;
    }

    public GameObject GetCamera()
    {
        return camera;
    }

    public override Vector3 GetMomentum()
    {
        //if (mounted) return dragon.GetMoveVector();
        //return rigidbody.velocity;
        return momentum;
    }

    public bool IsMounted()
    {
        return mounted;
    }

    protected override void Death()
    {
        
    }
}
