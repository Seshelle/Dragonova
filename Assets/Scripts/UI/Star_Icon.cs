using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class Star_Icon : MonoBehaviour
{
    public LineRenderer upLine;
    public LineRenderer rightLine;

    Strat_Map_Control stratMap;
    const float offsetMult = 0.8f;

    int cameraWidth;
    int cameraHeight;
    (int x, int y) gridPos = (999999, 999999);

    public void Init(int cx, int cy, int x, int y, Strat_Map_Control map)
    {
        stratMap = map;
        cameraWidth = cx;
        cameraHeight = cy;
        gridPos.x = x;
        gridPos.y = y;
        UpdateConnections();
    }

    public void UpdateConnections()
    {
        upLine.enabled = false;
        rightLine.enabled = false;

        if (IsVisible(gridPos))
        {
            Vector3 offset = GetRandomOffset(gridPos.x, gridPos.y);
            Vector3 newPos = new Vector3(gridPos.x, gridPos.y, 5) + offset;
            transform.position = newPos;

            var connections = GetConnections(gridPos);

            //draw line to connected visible stars
            if (connections.up && IsVisible((gridPos.x, gridPos.y + 1)))
            {
                upLine.enabled = true;
                upLine.SetPosition(1, Vector3.forward + Vector3.up + GetRandomOffset(gridPos.x, gridPos.y + 1) - offset);
            }
            if (connections.right && IsVisible((gridPos.x + 1, gridPos.y)))
            {
                rightLine.enabled = true;
                rightLine.SetPosition(1, Vector3.forward + Vector3.right + GetRandomOffset(gridPos.x + 1, gridPos.y) - offset);
            }
        }
    }

    public void CameraChange(int x, int y)
    {
        int xDiff = gridPos.x - x;
        int yDiff = gridPos.y - y;
        bool update = false;

        if (xDiff > cameraWidth)
        {
            update = true;
            gridPos.x -= cameraWidth * 2;
        }
        else if (xDiff < -cameraWidth)
        {
            update = true;
            gridPos.x += cameraWidth * 2;
        }

        if (yDiff > cameraHeight)
        {
            update = true;
            gridPos.y -= cameraHeight * 2;
        }
        else if (yDiff < -cameraHeight)
        {
            update = true;
            gridPos.y += cameraHeight * 2;
        }

        if (update) UpdateConnections();
    }

    public (int x, int y) GetGridPosition()
    {
        return gridPos;
    }

    public int GetSeed()
    {
        return gridPos.y + gridPos.x * 999999;
    }

    public bool IsVisible((int x, int y) pos)
    {
        var adjacentStars = ConnectedStars(pos);
        adjacentStars.Add(pos);

        foreach ((int x, int y) starPos in adjacentStars)
        {
            if (stratMap.IsDiscovered(starPos))
            {
                return true;
            }
        }
        return false;
    }

    static public (bool up, bool right) GetConnections((int x, int y) pos)
    {
        (bool up, bool right) connections = (true, true);

        //pick up, right, or both connections at random
        float rand = randAtLocation(pos.x, pos.y);
        if (rand < 0.25f)
        {
            connections.up = false;
        }
        else if (rand < 0.5f)
        {
            connections.right = false;
        }
        else if (rand < 0.75f)
        {
            //attempt to make zero connections, avoiding isolating this star
            //if at least one double connected star is connected to this, it is safe to make no connections
            if (randAtLocation(pos.x - 1, pos.y) > 0.75f || randAtLocation(pos.x, pos.y - 1) > 0.75f)
            {
                connections.up = false;
                connections.right = false;
            }
        }

        return connections;
    }

    static public List<(int x, int y)> ConnectedStars((int x, int y) pos)
    {
        var connections = GetConnections(pos);
        List<(int x, int y)> connectedStars = new List<(int x, int y)>();
        if (connections.up) connectedStars.Add((pos.x, pos.y + 1));
        if (connections.right) connectedStars.Add((pos.x + 1, pos.y));
        if (GetConnections((pos.x - 1, pos.y)).right) connectedStars.Add((pos.x - 1, pos.y));
        if (GetConnections((pos.x, pos.y - 1)).up) connectedStars.Add((pos.x, pos.y - 1));

        return connectedStars;
    }

    static private float randAtLocation(int x, int y)
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
