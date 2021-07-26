using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Star_Icon : MonoBehaviour
{
    public LineRenderer upLine;
    public LineRenderer rightLine;

    const float offsetMult = 0.8f;

    public enum Direction
    {
        up = 0,
        right = 1,
        down = 2,
        left = 3
    }

    int cameraWidth;
    int cameraHeight;
    int[] gridPos = { 999999, 999999 };

    public void Init(int cx, int cy, int x, int y)
    {
        cameraWidth = cx;
        cameraHeight = cy;
        gridPos[0] = x;
        gridPos[1] = y;
        UpdateConnections();
    }

    public void UpdateConnections()
    {
        upLine.enabled = true;
        rightLine.enabled = true;
        Vector3 offset = GetRandomOffset(gridPos[0], gridPos[1]);
        Vector3 newPos = new Vector3(gridPos[0], gridPos[1], 5) + offset;
        transform.position = newPos;

        //pick none, up, right, or both connections at random
        float rand = randAtLocation(gridPos[0], gridPos[1]);
        if (rand < 0.25f)
        {
            upLine.enabled = false;
        }
        else if (rand < 0.5f)
        {
            rightLine.enabled = false;
        }
        else if (rand < 0.75f)
        {
            //attempt to make zero connections, avoiding isolating this star
            //if at least one double connected star is connected to this, it is safe to make no connections
            if (randAtLocation(gridPos[0] - 1, gridPos[1]) > 0.75f || randAtLocation(gridPos[0], gridPos[1] - 1) > 0.75f)
            {
                upLine.enabled = false;
                rightLine.enabled = false;
            }
        }

        //draw line to connected stars
        if (upLine.enabled)
        {
            upLine.SetPosition(1, Vector3.forward + Vector3.up + GetRandomOffset(gridPos[0], gridPos[1] + 1) - offset);
        }
        if (rightLine.enabled)
        {
            rightLine.SetPosition(1, Vector3.forward + Vector3.right + GetRandomOffset(gridPos[0] + 1, gridPos[1]) - offset);
        }
    }

    public void CameraChange(int x, int y)
    {
        int xDiff = gridPos[0] - x;
        int yDiff = gridPos[1] - y;
        bool update = false;

        if (xDiff > cameraWidth)
        {
            update = true;
            gridPos[0] -= cameraWidth * 2;
        }
        else if (xDiff < -cameraWidth)
        {
            update = true;
            gridPos[0] += cameraWidth * 2;
        }

        if (yDiff > cameraHeight)
        {
            update = true;
            gridPos[1] -= cameraHeight * 2;
        }
        else if (yDiff < -cameraHeight)
        {
            update = true;
            gridPos[1] += cameraHeight * 2;
        }

        if (update) UpdateConnections();
    }

    public int[] GetGridPosition()
    {
        return gridPos;
    }

    public int GetSeed()
    {
        return gridPos[1] + gridPos[0] * 999999;
    }

    public bool IsConnected(int x, int y)
    {
        return true;
    }

    private float randAtLocation(int x, int y)
    {
        Random.InitState(y + x * 999999);
        return Random.value;
    }

    private Vector3 GetRandomOffset(int x, int y)
    {
        Random.InitState(x + y * 999999);
        return new Vector3(Random.value * offsetMult, Random.value * offsetMult, 0);
    }

}
