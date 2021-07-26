using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;

public class Exploration_UI : MonoBehaviour
{
    public Text healthValue;
    public Text FPS;
    int lastHealth = 0;

    float frameTimer = 0;
    int numFrames = 0;

    Player player;

    // Start is called before the first frame update
    void Start()
    {
        player = GameObject.FindGameObjectWithTag("Player").GetComponent<Player>();
    }

    // Update is called once per frame
    void Update()
    {
        //change health display only when the player's health changes
        int currentHealth = player.GetHealthAsInt();
        if (currentHealth != lastHealth)
        {
            lastHealth = currentHealth;
            healthValue.text = currentHealth.ToString();
        }

        //get average over last second
        numFrames += 1;
        frameTimer += Time.unscaledDeltaTime;
        if (frameTimer >= 0.2f)
        {
            FPS.text = Mathf.RoundToInt(numFrames / frameTimer).ToString();
            numFrames = 0;
            frameTimer = 0;
        }
    }
}
