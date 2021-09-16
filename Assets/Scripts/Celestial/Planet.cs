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
    public bool blur = true;

    //public float rotationSpeed = 0.005f;

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

    Cubemap heightMap;
    Dictionary<CubemapFace, Texture2D> planetFaces = new Dictionary<CubemapFace, Texture2D>();
    Material mat;
    float radius;
    float mainScale;
    float seaLevel;
    float worldSeaLevel;

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
        heightMap = new Cubemap(textureSize, TextureFormat.RG32, false);
        heightMap.anisoLevel = 0;
        heightMap.filterMode = FilterMode.Bilinear;
        Random.InitState(seed);
        const float range = 5000;
        xOrg = Random.value * range - range / 2;
        yOrg = Random.value * range - range / 2;

        //set each face around the equator
        CreateFace(CubemapFace.NegativeX, xOrg, yOrg);
        CreateFace(CubemapFace.NegativeZ, xOrg - heightMap.width, yOrg);
        CreateFace(CubemapFace.PositiveX, xOrg - heightMap.width * 2, yOrg);
        CreateFace(CubemapFace.PositiveZ, xOrg - heightMap.width * 3, yOrg);

        //cap the poles
        CreateFace(CubemapFace.NegativeY, xOrg, yOrg + heightMap.height);
        CreateFace(CubemapFace.PositiveY, xOrg, yOrg - heightMap.height);

        heightMap.Apply(false);
        if (!mat) mat = GetComponent<Renderer>().material;
        ApplyToSharedMaterial();
    }

    void CreateFace(CubemapFace face, float xStart, float yStart)
    {
        Color[] pixels = new Color[heightMap.width * heightMap.height];
        const float warpScale = 4f;
        for (float x = xStart; x < heightMap.width + xStart; x++)
        {
            for (float y = yStart; y < heightMap.height + yStart; y++)
            {
                float pixX = x / heightMap.width;
                float pixY = y / heightMap.height;
                float xCoord = xOrg + pixX;
                float yCoord = yOrg + pixY;

                float scaledX = xCoord * scale;
                float scaledY = yCoord * scale;
                float xWarp = FractalNoise(scaledX + 0.03f, scaledY + 0.037f) * warpScale;
                float yWarp = FractalNoise(scaledX + 0.043f, scaledY + 0.03f) * warpScale;
                float redChannel = FractalNoise(scaledX + xWarp, scaledY + yWarp);

                pixels[(int)(y - yStart) * heightMap.width + (int)(x - xStart)] = new Color(redChannel, 0, 0, 1);
            }
        }
        heightMap.SetPixels(pixels, face);
        planetFaces[face] = new Texture2D(heightMap.width, heightMap.height, TextureFormat.RG32, false);
        planetFaces[face].SetPixels(pixels);
        planetFaces[face].Apply(false);
    }

    void ApplyToSharedMaterial()
    {
        mat.SetTexture("_MainTex", heightMap);
    }

    void AddFoliage(int seed)
    {
        for (int i = 0; i < 100; i++)
        {
            Vector3 treePos = new Vector3(Random.value * 2 - 1, Random.value * 2 - 1, Random.value * 2 - 1).normalized;
            float altitude = GetPlanetHeight(treePos, 0);
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

    CubemapFace GetSurfaceFace(Vector3 p)
    {
        p = Vector3.Normalize(p);
        Vector3 pAbs = new Vector3(Mathf.Abs(p.x), Mathf.Abs(p.y), Mathf.Abs(p.z));

        if (pAbs.z >= pAbs.x && pAbs.z >= pAbs.y)
        {
            return p.z < 0 ? CubemapFace.NegativeZ : CubemapFace.PositiveZ;
        }
        else if (pAbs.y >= pAbs.x)
        {
            return p.z < 0 ? CubemapFace.NegativeY : CubemapFace.PositiveY;
        }
        else
        {
            return p.z < 0 ? CubemapFace.NegativeX : CubemapFace.PositiveX;
        }
    }

    Vector2 GetSurfaceUV(Vector3 p)
    {
        p = Vector3.Normalize(p);
        Vector3 pAbs = new Vector3(Mathf.Abs(p.x), Mathf.Abs(p.y), Mathf.Abs(p.z));
        float ma;
        Vector2 uv;

        if (pAbs.z >= pAbs.x && pAbs.z >= pAbs.y)
        {
            ma = 0.5f / pAbs.z;
            uv = new Vector2(p.z < 0 ? -p.x : p.x, -p.y) * ma;
        }
        else if (pAbs.y >= pAbs.x)
        {
            ma = 0.5f / pAbs.y;
            uv = new Vector2(p.x, p.y < 0 ? -p.z : p.z) * ma;
        }
        else
        {
            ma = 0.5f / pAbs.x;
            uv = new Vector2(p.x < 0 ? p.z : -p.z, -p.y) * ma;
        }

        return new Vector2(uv.x + 0.5f, uv.y + 0.5f);
    }

    public float GetPlanetHeight(Vector3 p, float size)
    {
        /*position = Quaternion.AngleAxis(-transform.rotation.eulerAngles.y, Vector3.up) * position;
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
        return height * transform.localScale.x + size;*/

        /*float2 sampleCube(
            const float3 v,
            out float faceIndex)
        {
            float3 vAbs = abs(v);
            float ma;
            float2 uv;
            if (vAbs.z >= vAbs.x && vAbs.z >= vAbs.y)
            {
                faceIndex = v.z < 0.0 ? 5.0 : 4.0;
                ma = 0.5 / vAbs.z;
                uv = float2(v.z < 0.0 ? -v.x : v.x, -v.y);
            }
            else if (vAbs.y >= vAbs.x)
            {
                faceIndex = v.y < 0.0 ? 3.0 : 2.0;
                ma = 0.5 / vAbs.y;
                uv = float2(v.x, v.y < 0.0 ? -v.z : v.z);
            }
            else
            {
                faceIndex = v.x < 0.0 ? 1.0 : 0.0;
                ma = 0.5 / vAbs.x;
                uv = float2(v.x < 0.0 ? v.z : -v.z, -v.y);
            }
            return uv * ma + 0.5;
        }*/

        Vector2 uv = GetSurfaceUV(p);
        CubemapFace face = GetSurfaceFace(p);
        int pixelX = Mathf.RoundToInt(uv.x * heightMap.width);
        int pixelY = Mathf.RoundToInt(uv.y * heightMap.height);

        //float height = heightMap.GetPixel(face, pixelX, pixelY).r;
        float adjust = 0.5f / textureSize;
        float height = planetFaces[face].GetPixelBilinear(uv.x - adjust, uv.y - adjust).r;
        height = radius - height * mainScale;
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
        /*position = Quaternion.AngleAxis(-transform.rotation.eulerAngles.y, Vector3.up) * position;
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
        ApplyToSharedMaterial();*/
    }
}
