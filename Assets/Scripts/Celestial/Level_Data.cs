using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Level_Data : MonoBehaviour
{
    bool initialized = false;

    int seed = 0;
    int[] position = { 0, 0 };

    void Awake()
    {
        if (!initialized)
        {
            if (GameObject.FindGameObjectsWithTag("LevelData").Length <= 1)
            {
                GameObject.DontDestroyOnLoad(gameObject);
                initialized = true;
            }
            else
            {
                GameObject.Destroy(gameObject);
            }
        }
    }

    public void SetSeed(int newSeed)
    {
        seed = newSeed;
    }

    public void SetPosition(int[] pos)
    {
        position = pos;
    }

    public int GetPlanetSeed()
    {
        return seed;
    }
}
