using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

public class Planet : MonoBehaviour
{
    // Width and height of the texture in pixels.
    public int textureSize = 1024;

    // The number of cycles of the basic noise pattern that are repeated
    // over the width and height of the texture.
    public float scale = 1.0F;

    public float rotationSpeed = 0.2f;

    float xOrg = 0;
    float yOrg = 0;

    public GameObject tree;

#if UNITY_EDITOR
    [CustomEditor(typeof(Planet))]
    public class SomeScriptEditor : Editor
    {
        public override void OnInspectorGUI()
        {
            DrawDefaultInspector();

            Planet myScript = (Planet)target;
            if (GUILayout.Button("Add Noise"))
            {
                myScript.CalcNoise(0);
            }
        }
    }
#endif

    private Texture2D noiseTex;
    //private Texture2D lowTex;
    private Color[] pix;
    private Material mat;
    private float radius;
    private float mainScale;
    private float seaLevel;
    private float worldSeaLevel;

    void Start()
    {
        //get level data to generate
        Level_Data levelData = GameObject.FindGameObjectWithTag("LevelData").GetComponent<Level_Data>();
        CalcNoise(levelData.GetPlanetSeed());

        //sync with current shader properties
        if (!mat) mat = GetComponent<Renderer>().material;
        radius = mat.GetFloat("_Radius");
        mainScale = mat.GetFloat("_Scale");
        seaLevel = mat.GetFloat("_SeaLevel");
        worldSeaLevel = (radius + seaLevel) * transform.localScale.x;

        AddFoliage(levelData.GetPlanetSeed());
    }

    /*float terrain(float2 p)
    {
        const float2x2 m2 = float2x2(0.80, 0.60, -0.60, 0.80);
        p *= 0.0045;
        float f = 2.;
        float s = 0.5;
        float a = 0.0;
        float b = 0.5;
        for (int i = 0; i < 9; i++)
        {
            float n = noise(p);
            a += b * n;
            b *= s;
            p = mul(p, m2) * f;
        }

        a = smoothstep(-0.5, 0.7, a);

        return a;
    }*/

    /*private void FixedUpdate()
    {
        transform.Rotate(Vector3.up * Time.deltaTime * rotationSpeed);
    }*/

    float FractalNoise(float x, float y)
    {
        const int octaves = 10;
        const float shift = 2;
        float value = 0;
        float amplitude = 0.5f;
        for (int i = 0; i < octaves; i++)
        {
            value += amplitude * Mathf.PerlinNoise(x, y);
            x *= shift;
            y *= shift;
            amplitude *= .5f;
        }
        return value;
    }

    public void CalcNoise(int seed)
    {
        noiseTex = new Texture2D(textureSize, textureSize, TextureFormat.RGBA64, false);
        noiseTex.anisoLevel = 0;
        noiseTex.wrapMode = TextureWrapMode.Mirror;
        noiseTex.filterMode = FilterMode.Bilinear;
        pix = new Color[noiseTex.width * noiseTex.height];
        Random.InitState(seed);
        const float range = 5000;
        xOrg = Random.value * range - range / 2;
        yOrg = Random.value * range - range / 2;

        float y = 0.0f;
        const float warpScale = 4f;

        while (y < noiseTex.height)
        {
            float x = 0.0f;
            while (x < noiseTex.width)
            {
                float pixX = x / noiseTex.width;
                float pixY = y / noiseTex.height;
                float xCoord = xOrg + pixX;
                float yCoord = yOrg + pixY;

                float scaledX = xCoord * scale;
                float scaledY = yCoord * scale;
                //float xWarp = FractalNoise(scaledX + 2.3f, scaledY + 0.37f) * warpScale;
                //float yWarp = FractalNoise(scaledX + 5.2f, scaledY + 1.3f) * warpScale;
                float xWarp = FractalNoise(scaledX + 0.03f, scaledY + 0.037f) * warpScale;
                float yWarp = FractalNoise(scaledX + 0.043f, scaledY + 0.03f) * warpScale;
                float redChannel = FractalNoise(scaledX + xWarp, scaledY + yWarp);
                //float randomBump = Random.value;
                //redChannel += (randomBump * randomBump) / 300;

                pix[(int)y * noiseTex.width + (int)x] = new Color(redChannel, 0, 0, 1);
                x++;
            }
            y++;
        }

        // Copy the pixel data to the texture and load it into the GPU.
        noiseTex.SetPixels(pix);
        noiseTex.Apply(false);
        if (!mat) mat = GetComponent<Renderer>().material;
        ApplyToSharedMaterial();
    }

    void ApplyToSharedMaterial()
    {
        mat.SetTexture("_MainTex", noiseTex);
    }

    void AddFoliage(int seed)
    {
        for (int i = 0; i < 10000; i++)
        {
            Vector3 treePos = new Vector3(Random.value * 2 - 1, Random.value * 2 - 1, Random.value * 2 - 1).normalized;
            float altitude = GetPlanetHeight(treePos, -1);
            if (altitude > worldSeaLevel)
            {
                Quaternion treeRot = Quaternion.LookRotation(-treePos) * Quaternion.Euler(-90, 0, 0);
                GameObject.Instantiate(tree, treePos * altitude, treeRot);
            }
        }
    }

    public bool IsInPlanet(Vector3 pos)
    {
        return pos.magnitude <= GetPlanetHeight(pos);
    }

    public float DistanceToPlanet(Vector3 pos)
    {
        return pos.magnitude - GetPlanetHeight(pos);
    }

    Vector2 getSphereUV(Vector3 p)
    {
        Vector3 octant = new Vector3(p.x > 0 ? 1 : -1, p.y > 0 ? 1 : -1, p.z > 0 ? 1 : -1);

        float sum = Vector3.Dot(p, octant);
        Vector3 octahedron = p / sum;

        Vector2 octxy = new Vector2(octahedron.x, octahedron.y);
        if (octahedron.z < 0)
        {
            Vector3 absolute = new Vector3(Mathf.Abs(octahedron.x), Mathf.Abs(octahedron.y), Mathf.Abs(octahedron.z));
            octxy = new Vector2(octant.x, octant.y) * new Vector2(1.0f - absolute.y, 1.0f - absolute.x);
        }

        octxy = new Vector2(octxy.x + 1f, octxy.y + 1f) * 0.5f;

        return octxy;
    }

    Vector2 difSphereUV(Vector3 p)
    {
        Vector3 octant = new Vector3(p.x > 0 ? 1 : -1, p.y > 0 ? 1 : -1, p.z > 0 ? 1 : -1);

        float sum = Vector3.Dot(p, octant);
        Vector3 octahedron = p / sum;

        return new Vector2(octahedron.x + 1.2f, octahedron.y + 1.2f) * 0.5f;
    }

    public float GetPlanetHeight(Vector3 position, float size)
    {
        position = Quaternion.AngleAxis(-transform.rotation.eulerAngles.y, Vector3.up) * position;
        Vector2 uv = getSphereUV(position);

        float adjustX = 0.5f / textureSize;
        float adjustY = 0.5f / textureSize;
        Color col = noiseTex.GetPixelBilinear(uv.x - adjustX, uv.y - adjustY);

        float blend = Mathf.Max(Mathf.Abs(uv.x - 0.5f), Mathf.Abs(uv.y - 0.5f));
        if (blend > 0)
        {
            Vector2 difUV = difSphereUV(position);
            Color adj = noiseTex.GetPixelBilinear(difUV.x - adjustX, difUV.y - adjustY);
            adj = new Color(adj.r, col.g, 0);
            col = Color.Lerp(col, adj, blend * 2);
        }
        float height = radius - (col.r + col.g) * mainScale;
        return height * transform.localScale.x + size;
    }

    public float GetPlanetHeight(Vector3 position)
    {
        return GetPlanetHeight(position, 0);
    }

    public Vector3 GetNormalFromPosition(Vector3 position)
    {
        float e = 0.1f;
        Vector3 xyy = new Vector3(e, 0, 0);
        Vector3 yxy = new Vector3(0, e, 0);
        Vector3 yxx = new Vector3(0, e, e);
        float d = GetPlanetHeight(position);
        Vector3 nd = new Vector3(d, d, d);
        Vector3 n = nd - new Vector3(
                    GetPlanetHeight(position - xyy),
                    GetPlanetHeight(position - yxy),
                    GetPlanetHeight(position - yxx)
                    );
        return n.normalized;
    }

    public Vector3 ClosestContact(Vector3 position)
    {
        return position.normalized * GetPlanetHeight(position);
    }

    public void Terraform(Vector3 position, int radius, float amount)
    {
        position = Quaternion.AngleAxis(-transform.rotation.eulerAngles.y, Vector3.up) * position;
        Color elevationChange = new Color(0, amount, 0);
        Vector2 uv = getSphereUV(position);
        uv.x -= 0.5f / textureSize;
        uv.y -= 0.5f / textureSize;

        int xPix = Mathf.RoundToInt(textureSize * uv.x);
        int yPix = Mathf.RoundToInt(textureSize * uv.y);

        for (int x = xPix - radius; x <= xPix + radius; x++)
        {
            for (int y = yPix - radius; y <= yPix + radius; y++)
            {
                Color pixCol = noiseTex.GetPixel(x, y);
                noiseTex.SetPixel(x, y, pixCol + elevationChange);
            }
        }
        noiseTex.Apply(false);
        ApplyToSharedMaterial();
    }
}
