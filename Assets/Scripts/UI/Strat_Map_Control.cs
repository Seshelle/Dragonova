using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

public class Strat_Map_Control : MonoBehaviour
{
    public float scrollSpeed;
    public float maxCameraSize;
    public float minCameraSize;
    public Star_Icon star;

    Camera camera;
    int cameraHeight;
    int cameraWidth;
    Star_Icon[,] stars;
    int prevX = 0;
    int prevY = 0;
    Level_Data level;

    private void Start()
    {
        camera = GetComponent<Camera>();
        cameraHeight = Mathf.RoundToInt(camera.orthographicSize) + 2;
        cameraWidth = Mathf.RoundToInt(camera.orthographicSize * Screen.width / Screen.height) + 2;
        stars = new Star_Icon[cameraWidth * 2, cameraHeight * 2];
        for(int x = 0; x < cameraWidth * 2; x++)
        {
            for(int y = 0; y < cameraHeight * 2; y++)
            {
                stars[x, y] = GameObject.Instantiate(star.gameObject).GetComponent<Star_Icon>();
                stars[x, y].Init(cameraWidth, cameraHeight, x - cameraWidth, y - cameraHeight);
            }
        }

        level = GameObject.FindGameObjectWithTag("LevelData").GetComponent<Level_Data>();

        //force the map to update by changing prevX
        prevX = Mathf.RoundToInt(transform.position.x) + 1;
    }

    private void Update()
    {
        float speed = Time.deltaTime * scrollSpeed;
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

        if (Input.GetMouseButtonDown(0))
        {
            Ray ray = Camera.main.ScreenPointToRay(Input.mousePosition);
            RaycastHit2D hit = Physics2D.GetRayIntersection(ray, 10);

            if (hit.collider)
            {
                Star_Icon starHit = hit.collider.gameObject.GetComponent<Star_Icon>();
                if (starHit)
                {
                    level.SetPosition(starHit.GetGridPosition());
                    level.SetSeed(starHit.GetSeed());
                    //print(starPos[0] + ", " + starPos[1]);
                    SceneManager.LoadScene("Test");
                }
            }
        }
    }

    private void FixedUpdate()
    {
        //put a star in each visible position
        int cameraX = Mathf.RoundToInt(transform.position.x);
        int cameraY = Mathf.RoundToInt(transform.position.y);

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
                    //stars[x, y].UpdateConnections(x + startX, y + startY);
                    stars[x, y].CameraChange(cameraX, cameraY);
                }
            }
        }
    }
}
