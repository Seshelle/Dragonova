using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Grappling_Hook : Projectile
{
    public float force = 100;
    public Player player;

    Rigidbody playerRigidbody;
    bool grappling = false;

    LineRenderer line;

    // Start is called before the first frame update
    override protected void Awake()
    {
        base.Awake();
        resting = true;
        player = GameObject.FindGameObjectWithTag("Player").GetComponent<Player>();
        playerRigidbody = player.GetComponent<Rigidbody>();
        line = GetComponent<LineRenderer>();
        line.SetPositions(new Vector3[] { Vector3.zero, Vector3.zero });
    }

    private void Update()
    {
        if (grappling || !resting)
        {
            Transform playerCam = player.GetCamera().transform;
            line.SetPositions(new Vector3[] { playerCam.position + playerCam.forward * 0.9f + playerCam.right * 0.3f - playerCam.up * 0.15f, transform.position });
        }
    }

    protected override void FixedUpdate()
    {
        base.FixedUpdate();
        if (grappling)
        {
            //pull player towards hook point until they are close
            Vector3 direction = transform.position - player.transform.position;
            if (!player.IsGrappling()) SetGrapple(false);

            if (Vector3.Dot(direction.normalized, playerRigidbody.velocity.normalized) < 0)
            {
                //rotate velocity towards point until 90 degrees from point
                Vector3 curVel = playerRigidbody.velocity;
                float angle = Vector3.Angle(curVel.normalized, direction.normalized);
                angle = (angle / 360f) * Mathf.PI * 2f;
                playerRigidbody.velocity = Vector3.RotateTowards(curVel.normalized, direction.normalized, angle - Mathf.PI / 2f, 100000) * curVel.magnitude;
            }
            playerRigidbody.AddForce(Vector3.Normalize(direction) * force, ForceMode.Acceleration);
        }
       
    }

    public void StartGrapple()
    {
        //player.SetGrappling(true);
        activeTime = 0;
        grappling = false;
        resting = false;
    }

    void SetGrapple(bool state)
    {
        player.SetGrappling(state);
        grappling = state;
        resting = true;
        line.SetPositions(new Vector3[] { Vector3.zero, Vector3.zero });
        if (!grappling)
        {
            transform.parent = null;
            transform.position = Vector3.zero;
        }
        else
        {
            rigidbody.velocity = Vector3.zero;
        }
    }

    override public void SetResting(bool state)
    {
        SetGrapple(false);
    }

    protected override void HitPlanet()
    {
        SetGrapple(true);
        transform.parent = manager.GetClosestPlanet(transform.position).transform;
    }

    protected override void OnTriggerEnter(Collider other)
    {
        if (!other.isTrigger && !other.gameObject.CompareTag("Player"))
        {
            SetGrapple(true);
            transform.parent = other.transform;
        }
    }
}
