using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

public class Strat_Map_Control : MonoBehaviour
{
    public float scrollSpeed;
    public float maxCameraSize;
    public float minCameraSize;
    public Star_Icon star;
    public Text loadingText;
    public Text coordinateText;

    Camera camera;
    int cameraHeight;
    int cameraWidth;
    Star_Icon[,] stars;
    int prevX = 0;
    int prevY = 0;
    Level_Data level;
    List<(int x, int y)> discoveredStars = new List<(int x, int y)>();

    private void Start()
    {
        discoveredStars.Add((0, 0));
        camera = GetComponent<Camera>();
        cameraHeight = Mathf.RoundToInt(camera.orthographicSize) + 2;
        cameraWidth = Mathf.RoundToInt(camera.orthographicSize * Screen.width / Screen.height) + 2;
        stars = new Star_Icon[cameraWidth * 2, cameraHeight * 2];
        for(int x = 0; x < cameraWidth * 2; x++)
        {
            for(int y = 0; y < cameraHeight * 2; y++)
            {
                stars[x, y] = GameObject.Instantiate(star.gameObject).GetComponent<Star_Icon>();
                stars[x, y].Init(cameraWidth, cameraHeight, x - cameraWidth, y - cameraHeight, this);
            }
        }

        level = GameObject.FindGameObjectWithTag("LevelData").GetComponent<Level_Data>();
        CheckMapUpdate(true);
    }

    private void Update()
    {
        float speed = Time.deltaTime * scrollSpeed;
        if (Input.GetButton("Sprint")) speed *= 2;
        float horizontal = Input.GetAxisRaw("Horizontal") * speed;
        float vertical = Input.GetAxisRaw("Vertical") * speed;
        transform.Translate(horizontal, vertical, 0);

        camera.orthographicSize -= Input.mouseScrollDelta.y;
        if (camera.orthographicSize > maxCameraSize)
        {
            camera.orthographicSize = maxCameraSize;
        }
        else if (camera.orthographicSize < minCameraSize)
        {
            camera.orthographicSize = minCameraSize;
        }

        Ray ray = Camera.main.ScreenPointToRay(Input.mousePosition);
        RaycastHit2D hit = Physics2D.GetRayIntersection(ray, 10);

        if (hit.collider)
        {
            Star_Icon starHit = hit.collider.gameObject.GetComponent<Star_Icon>();
            if (starHit)
            {
                (int x, int y) coord = starHit.GetGridPosition();
                coordinateText.text = $"{coord.x}, {coord.y}";
                if (Input.GetMouseButtonDown(0))
                {
                    discoveredStars.Add(coord);
                    level.SetPosition(coord);
                    level.SetSeed(starHit.GetSeed());
                    loadingText.enabled = true;
                    SceneManager.LoadScene("Test");
                }
            }
        }
    }

    private void FixedUpdate()
    {
        CheckMapUpdate();
    }

    private void CheckMapUpdate()
    {
        CheckMapUpdate(false);
    }

    private void CheckMapUpdate(bool forceUpdate)
    {
        //put a star in each visible position
        int cameraX = Mathf.RoundToInt(transform.position.x);
        int cameraY = Mathf.RoundToInt(transform.position.y);

        if (forceUpdate)
        {
            cameraX += 999999;
            cameraY += 999999;
        }

        if (cameraX != prevX || cameraY != prevY)
        {
            prevX = cameraX;
            prevY = cameraY;
            int startX = cameraX - cameraWidth;
            int startY = cameraY - cameraHeight;

            for (int x = 0; x < cameraWidth * 2; x++)
            {
                for (int y = 0; y < cameraHeight * 2; y++)
                {
                    stars[x, y].CameraChange(cameraX, cameraY);
                }
            }
        }
    }

    public bool IsDiscovered((int x, int y) pos)
    {
        return discoveredStars.Contains(pos);
    }
}
