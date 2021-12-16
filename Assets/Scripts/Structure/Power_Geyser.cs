using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Power_Geyser : MonoBehaviour
{
    public void SetActive(bool active)
    {
        foreach ( var particle in GetComponentsInChildren<ParticleSystem>())
        {
            if (!active) particle.Stop();
            else particle.Play();
        }
    }
}
