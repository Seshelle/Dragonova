using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

public class Planet_Manager : MonoBehaviour
{
    public static bool gamePaused = false;
    GameObject[] planetList;
    GameObject player;
    HashSet<GameObject> targetList = new HashSet<GameObject>();

    private void Start()
    {
        player = GameObject.FindGameObjectWithTag("Player");
        planetList = GameObject.FindGameObjectsWithTag("Planet");
    }

    private void Update()
    {
        if (Input.GetButtonDown("Cancel"))
        {
            gamePaused = !gamePaused;
            if (gamePaused)
            {
                Time.timeScale = 0;
            }
            else
            {
                Time.timeScale = 1;
            }
        }
    }

    private void FixedUpdate()
    {
        if (Vector3.Magnitude(player.transform.position) > 30000)
        {
            SceneManager.LoadScene("Strategy_Map");
        }
    }

    public Planet GetClosestPlanet(Vector3 position)
    {
        float minDist = 99999999;
        float dist;
        Vector3 planetLocation = planetList[0].transform.position;
        GameObject closestPlanet = planetList[0];
        foreach(GameObject planet in planetList)
        {
            dist = Vector3.Magnitude(planet.transform.position - position);
            if (dist < minDist)
            {
                minDist = dist;
                planetLocation = planet.transform.position;
                closestPlanet = planet;
            }
        }
        return closestPlanet.GetComponent<Planet>();
    }

    public float GetDistanceFromPlanets(Vector3 position)
    {
        float minDist = 99999999;
        float dist;
        Vector3 planetLocation = planetList[0].transform.position;
        GameObject closestPlanet = planetList[0];
        foreach (GameObject planet in planetList)
        {
            dist = Vector3.Magnitude(planet.transform.position - position);
            if (dist < minDist)
            {
                minDist = dist;
                planetLocation = planet.transform.position;
                closestPlanet = planet;
            }
        }
        Planet close = closestPlanet.GetComponent<Planet>();
        return minDist - close.GetPlanetHeight(position);
    }

    public HashSet<GameObject> GetAllTargets()
    {
        return targetList;
    }

    public GameObject ClosestTarget(Vector3 pos)
    {
        float minDist = 9999999;
        GameObject target = null;
        foreach (GameObject g in targetList)
        {
            float dist = Vector3.Distance(pos, g.transform.position);
            if (dist < minDist && dist > 0)
            {
                minDist = dist;
                target = g;
            }
        }
        return target;
    }

    public void AddToTargetList(GameObject target)
    {
        targetList.Add(target);
    }

    public void RemoveFromTargetList(GameObject target)
    {
        targetList.Remove(target);
    }
}
