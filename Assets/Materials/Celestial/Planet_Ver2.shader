Shader "Unlit/Planet_Shader_Ver2"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
		_Radius("Radius", float) = 0.4
		_Scale("Scale", float) = 2
		_DetailScale("Detail Scale", float) = 1
		_SeaLevel("Sea Level", float) = 0.45
	}
		SubShader
		{
			Tags { "RenderType" = "Opaque" }
			LOD 100
			Cull Off

			Pass
			{
				CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag
				// make fog work
				#pragma multi_compile_fog

				#include "UnityCG.cginc"

				#define MAX_DIST 100
				#define MAX_STEPS 300
				#define EPSILON 0.0001

				struct appdata
				{
					float4 vertex : POSITION;
				};

				struct v2f
				{
					float4 vertex : SV_POSITION;
					float3 ro : TEXCOORD1;
					float3 hitPos : TEXCOORD2;
					float4 time : TEXCOORD3;
				};

				sampler2D _MainTex;
				float4 _MainTex_ST;
				float _Radius;
				float _Scale;
				float _DetailScale;
				float _SeaLevel;

				v2f vert(appdata v)
				{
					v2f o;
					o.vertex = UnityObjectToClipPos(v.vertex);
					o.ro = mul(unity_WorldToObject, float4(_WorldSpaceCameraPos, 1));
					o.hitPos = v.vertex;
					o.time = _Time;
					return o;
				}

				// first, lets define some constants to use (planet radius, position, and scattering coefficients)
				#define PLANET_POS 0 /* the position of the planet */
				#define PLANET_RADIUS 0.4 /* radius of the planet */
				#define ATMOS_RADIUS 0.5 /* radius of the atmosphere */
				// scattering coeffs
				#define RAY_BETA float3(5.5e-6, 13.0e-6, 22.4e-6) /* rayleigh, affects the color of the sky */
				#define MIE_BETA 21e-6 /* mie, affects the color of the blob around the sun */
				#define AMBIENT_BETA 0 /* ambient, affects the scattering color when there is no lighting from the sun */
				#define ABSORPTION_BETA float3(2.04e-5, 4.97e-5, 1.95e-6) /* what color gets absorbed by the atmosphere (Due to things like ozone) */
				#define G 0.7 /* mie scattering direction, or how big the blob around the sun is */
				// and the heights (how far to go up before the scattering has no effect)
				#define HEIGHT_RAY 8e3 /* rayleigh height */
				#define HEIGHT_MIE 1.2e3 /* and mie */
				#define HEIGHT_ABSORPTION 0.4 /* at what height the absorption is at it's maximum */
				#define ABSORPTION_FALLOFF 4e3 /* how much the absorption decreases the further away it gets from the maximum height */
				// and the steps (more looks better, but is slower)
				// the primary step has the most effect on looks
				#if HW_PERFORMANCE==0
				// edit these if you are on mobile
				#define PRIMARY_STEPS 12 
				#define LIGHT_STEPS 4
				# else
				// and these on desktop
				#define PRIMARY_STEPS 32 /* primary steps, affects quality the most */
				#define LIGHT_STEPS 8 /* light steps, how much steps in the light direction are taken */
				#endif

				// camera mode, 0 is on the ground, 1 is in space, 2 is moving, 3 is moving from ground to space
				#define CAMERA_MODE 2

				float getHeight(float3 p) {

					p = normalize(p);
					float colXZ = 0;
					float colYZ = 0;
					float colXY = 0;

					float3 DXZ = tex2Dlod(_MainTex, float4(p.xz*.5 + .5, 0, 0));
					float3 DYZ = tex2Dlod(_MainTex, float4(p.yz*.5 + .5, 0, 0));
					float3 DXY = tex2Dlod(_MainTex, float4(p.xy*.5 + .5, 0, 0));

					colXZ += DXZ.r * _Scale + DXZ.g * _DetailScale;
					colYZ += DYZ.r * _Scale + DYZ.g * _DetailScale;
					colXY += DXY.r * _Scale + DXY.g * _DetailScale;

					//colXZ += tex2D(_MainTex, p.xz * 100).r / 5000;
					//colYZ += tex2D(_MainTex, p.yz * 100).r / 5000;
					//colXY += tex2D(_MainTex, p.xy * 100).r / 5000;

					p = abs(p);
					p *= p;
					p /= p.x + p.y + p.z;

					return colYZ * p.x + colXZ * p.y + colXY * p.z;
				}

				float getDist(float3 p) {
					float height = getHeight(p);
					float land = length(p) - _Radius - height;
					float ocean = length(p) - _SeaLevel - _Radius;
					return min(land, ocean);
				}

				float4 raymarch(float3 ro, float3 rd) {
					float dO = 0;
					float dS;
					float3 p = 0;
					[loop]for (int i = 0; i < MAX_STEPS; i++) {
						p = ro + dO * rd;
						dS = getDist(p);
						dO += dS / 2.;
						if (dS < EPSILON || dO > MAX_DIST) break;
					}
					return float4(p, dO);
				}

				float3 getNormal(float3 pos)
				{
					float2 e = float2(1.0, -1.0)*0.5773*0.0005;
					return normalize(e.xyy*getDist(pos + e.xyy) +
						e.yyx*getDist(pos + e.yyx) +
						e.yxy*getDist(pos + e.yxy) +
						e.xxx*getDist(pos + e.xxx));
				}

				/*
				Next we'll define the main scattering function.
				This traces a ray from start to end and takes a certain amount of samples along this ray, in order to calculate the color.
				For every sample, we'll also trace a ray in the direction of the light,
				because the color that reaches the sample also changes due to scattering
*/
				float3 calculate_scattering(
					float3 start, 				// the start of the ray (the camera position)
					float3 dir, 					// the direction of the ray (the camera vector)
					float max_dist, 			// the maximum distance the ray can travel (because something is in the way, like an object)
					float3 scene_color,			// the color of the scene
					float3 light_dir, 			// the direction of the light
					float3 light_intensity,		// how bright the light is, affects the brightness of the atmosphere
					float3 planet_position, 		// the position of the planet
					float planet_radius, 		// the radius of the planet
					float atmo_radius, 			// the radius of the atmosphere
					float3 beta_ray, 				// the amount rayleigh scattering scatters the colors (for earth: causes the blue atmosphere)
					float3 beta_mie, 				// the amount mie scattering scatters colors
					float3 beta_absorption,   	// how much air is absorbed
					float3 beta_ambient,			// the amount of scattering that always occurs, cna help make the back side of the atmosphere a bit brighter
					float g, 					// the direction mie scatters the light in (like a cone). closer to -1 means more towards a single direction
					float height_ray, 			// how high do you have to go before there is no rayleigh scattering?
					float height_mie, 			// the same, but for mie
					float height_absorption,	// the height at which the most absorption happens
					float absorption_falloff,	// how fast the absorption falls off from the absorption height
					int steps_i, 				// the amount of steps along the 'primary' ray, more looks better but slower
					int steps_l 				// the amount of steps along the light ray, more looks better but slower
				) {
					// add an offset to the camera position, so that the atmosphere is in the correct position
					start -= planet_position;
					// calculate the start and end position of the ray, as a distance along the ray
					// we do this with a ray sphere intersect
					float a = dot(dir, dir);
					float b = 2.0 * dot(dir, start);
					float c = dot(start, start) - (atmo_radius * atmo_radius);
					float d = (b * b) - 4.0 * a * c;

					// stop early if there is no intersect
					if (d < 0.0) return scene_color;

					// calculate the ray length
					float2 ray_length = float2(
						max((-b - sqrt(d)) / (2.0 * a), 0.0),
						min((-b + sqrt(d)) / (2.0 * a), max_dist)
					);

					// if the ray did not hit the atmosphere, return a black color
					if (ray_length.x > ray_length.y) return scene_color;
					// prevent the mie glow from appearing if there's an object in front of the camera
					bool allow_mie = max_dist > ray_length.y;
					// make sure the ray is no longer than allowed
					ray_length.y = min(ray_length.y, max_dist);
					ray_length.x = max(ray_length.x, 0.0);
					// get the step size of the ray
					float step_size_i = (ray_length.y - ray_length.x) / float(steps_i);

					// next, set how far we are along the ray, so we can calculate the position of the sample
					// if the camera is outside the atmosphere, the ray should start at the edge of the atmosphere
					// if it's inside, it should start at the position of the camera
					// the min statement makes sure of that
					float ray_pos_i = ray_length.x + step_size_i * 0.5;

					// these are the values we use to gather all the scattered light
					float3 total_ray = 0; // for rayleigh
					float3 total_mie = 0; // for mie

					// initialize the optical depth. This is used to calculate how much air was in the ray
					float3 opt_i = 0;

					// we define the density early, as this helps doing integration
					// usually we would do riemans summing, which is just the squares under the integral area
					// this is a bit innefficient, and we can make it better by also taking the extra triangle at the top of the square into account
					// the starting value is a bit inaccurate, but it should make it better overall
					float3 prev_density = 0;

					// also init the scale height, avoids some float2's later on
					float2 scale_height = float2(height_ray, height_mie);

					// Calculate the Rayleigh and Mie phases.
					// This is the color that will be scattered for this ray
					// mu, mumu and gg are used quite a lot in the calculation, so to speed it up, precalculate them
					float mu = dot(dir, light_dir);
					float mumu = mu * mu;
					float gg = g * g;
					float phase_ray = 3.0 / (50.2654824574 /* (16 * pi) */) * (1.0 + mumu);
					float phase_mie = allow_mie ? 3.0 / (25.1327412287 /* (8 * pi) */) * ((1.0 - gg) * (mumu + 1.0)) / (pow(1.0 + gg - 2.0 * mu * g, 1.5) * (2.0 + gg)) : 0.0;

					// now we need to sample the 'primary' ray. this ray gathers the light that gets scattered onto it
					for (int i = 0; i < steps_i; ++i) {

						// calculate where we are along this ray
						float3 pos_i = start + dir * ray_pos_i;

						// and how high we are above the surface
						float height_i = length(pos_i) - planet_radius;

						// now calculate the density of the particles (both for rayleigh and mie)
						float3 density = float3(exp(-height_i / scale_height), 0.0);

						// and the absorption density. this is for ozone, which scales together with the rayleigh, 
						// but absorbs the most at a specific height, so use the sech function for a nice curve falloff for this height
						// clamp it to avoid it going out of bounds. This prevents weird black spheres on the night side
						float denom = (height_absorption - height_i) / absorption_falloff;
						density.z = (1.0 / (denom * denom + 1.0)) * density.x;

						// multiply it by the step size here
						// we are going to use the density later on as well
						density *= step_size_i;

						// Add these densities to the optical depth, so that we know how many particles are on this ray.
						// max here is needed to prevent opt_i from potentially becoming negative
						opt_i += max(density + (prev_density - density) * 0.5, 0.0);

						// and update the previous density
						prev_density = density;

						// Calculate the step size of the light ray.
						// again with a ray sphere intersect
						// a, b, c and d are already defined
						a = dot(light_dir, light_dir);
						b = 2.0 * dot(light_dir, pos_i);
						c = dot(pos_i, pos_i) - (atmo_radius * atmo_radius);
						d = (b * b) - 4.0 * a * c;

						// no early stopping, this one should always be inside the atmosphere
						// calculate the ray length
						float step_size_l = (-b + sqrt(d)) / (2.0 * a * float(steps_l));

						// and the position along this ray
						// this time we are sure the ray is in the atmosphere, so set it to 0
						float ray_pos_l = step_size_l * 0.5;

						// and the optical depth of this ray
						float3 opt_l = 0;

						// again, use the prev density for better integration
						float3 prev_density_l = 0;

						// now sample the light ray
						// this is similar to what we did before
						for (int l = 0; l < steps_l; ++l) {

							// calculate where we are along this ray
							float3 pos_l = pos_i + light_dir * ray_pos_l;

							// the heigth of the position
							float height_l = length(pos_l) - planet_radius;

							// calculate the particle density, and add it
							// this is a bit verbose
							// first, set the density for ray and mie
							float3 density_l = float3(exp(-height_l / scale_height), 0.0);

							// then, the absorption
							float denom = (height_absorption - height_l) / absorption_falloff;
							density_l.z = (1.0 / (denom * denom + 1.0)) * density_l.x;

							// multiply the density by the step size
							density_l *= step_size_l;

							// and add it to the total optical depth
							opt_l += max(density_l + (prev_density_l - density_l) * 0.5, 0.0);

							// and update the previous density
							prev_density_l = density_l;

							// and increment where we are along the light ray.
							ray_pos_l += step_size_l;

						}

						// Now we need to calculate the attenuation
						// this is essentially how much light reaches the current sample point due to scattering
						float3 attn = exp(-beta_ray * (opt_i.x + opt_l.x) - beta_mie * (opt_i.y + opt_l.y) - beta_absorption * (opt_i.z + opt_l.z));

						// accumulate the scattered light (how much will be scattered towards the camera)
						total_ray += density.x * attn;
						total_mie += density.y * attn;

						// and increment the position on this ray
						ray_pos_i += step_size_i;

					}

					// calculate how much light can pass through the atmosphere
					float3 opacity = exp(-(beta_mie * opt_i.y + beta_ray * opt_i.x + beta_absorption * opt_i.z));

					// calculate and return the final color
					return (
						phase_ray * beta_ray * total_ray // rayleigh color
						+ phase_mie * beta_mie * total_mie // mie
						+ opt_i.x * beta_ambient // and ambient
						) * light_intensity + scene_color * opacity; // now make sure the background is rendered correctly
				}

				float2 ray_sphere_intersect(
					float3 start, // starting position of the ray
					float3 dir, // the direction of the ray
					float radius // and the sphere radius
				) {
					// ray-sphere intersection that assumes
					// the sphere is centered at the origin.
					// No intersection when result.x > result.y
					float a = dot(dir, dir);
					float b = 2.0 * dot(dir, start);
					float c = dot(start, start) - (radius * radius);
					float d = (b*b) - 4.0*a*c;
					if (d < 0.0) return float2(1e5, -1e5);
					return float2(
						(-b - sqrt(d)) / (2.0*a),
						(-b + sqrt(d)) / (2.0*a)
					);
				}

				float3 skylight(float3 sample_pos, float3 surface_normal, float3 light_dir, float3 background_col) {

					// slightly bend the surface normal towards the light direction
					surface_normal = normalize(lerp(surface_normal, light_dir, 0.6));

					// and sample the atmosphere
					return calculate_scattering(
						sample_pos,						// the position of the camera
						surface_normal, 				// the camera vector (ray direction of this pixel)
						3.0 * ATMOS_RADIUS, 			// max dist, since nothing will stop the ray here, just use some arbitrary value
						background_col,					// scene color, just the background color here
						light_dir,						// light direction
						40.0,						// light intensity, 40 looks nice
						PLANET_POS,						// position of the planet
						PLANET_RADIUS,                  // radius of the planet in meters
						ATMOS_RADIUS,                   // radius of the atmosphere in meters
						RAY_BETA,						// Rayleigh scattering coefficient
						MIE_BETA,                       // Mie scattering coefficient
						ABSORPTION_BETA,                // Absorbtion coefficient
						AMBIENT_BETA,					// ambient scattering, turned off for now. This causes the air to glow a bit when no light reaches it
						G,                          	// Mie preferred scattering direction
						HEIGHT_RAY,                     // Rayleigh scale height
						HEIGHT_MIE,                     // Mie scale height
						HEIGHT_ABSORPTION,				// the height at which the most absorption happens
						ABSORPTION_FALLOFF,				// how fast the absorption falls off from the absorption height
						LIGHT_STEPS, 					// steps in the ray direction
						LIGHT_STEPS 					// steps in the light direction
					);
				}

				/*
				The following function returns the scene color and depth
				(the color of the pixel without the atmosphere, and the distance to the surface that is visible on that pixel)

				in this case, the function renders a green sphere on the place where the planet should be
				color is in .xyz, distance in .w

				I won't explain too much about how this works, since that's not the aim of this shader
				*/
				float4 render_scene(float3 pos, float3 dir, float3 light_dir, float4 color) {

					// get where the ray intersects the planet
					float4 hit = raymarch(pos, dir);
					float t = hit.w;

					// if the ray hit the planet, set the max distance to that ray
					if (t < MAX_DIST) {
						color.w = t;

					}
					else {
						// add a sun, if the angle between the ray direction and the light direction is small enough, color the pixels white
						color.xyz = dot(dir, light_dir) > 0.9998 ? 3.0 : 0.0;
						color.w = 10000;
					}

					return color;
				}

				float3 getColor(float3 p) {

					p = normalize(p);
					float3 colXZ = 0;
					float3 colYZ = 0;
					float3 colXY = 0;

					colXZ += tex2D(_MainTex, p.xz*.5 + .5);
					colYZ += tex2D(_MainTex, p.yz*.5 + .5);
					colXY += tex2D(_MainTex, p.xy*.5 + .5);

					p = abs(p);
					p *= pow(p, 1);
					p /= p.x + p.y + p.z;

					return colYZ * p.x + colXZ * p.y + colXY * p.z;
				}

				float calcSoftshadow(float3 ro, float3 rd, float tmax)
				{
					float res = 1.0;
					float t = 0.001;
					float ph = 1e10; // big, such that y = 0 on the first iteration

					[loop]for (int i = 0; i < 300; i++)
					{
						float h = getDist(ro + rd * t);
						float y = h * h / (2.0*ph);
						float d = sqrt(h*h - y * y);
						res = min(res, 10.0*d / max(0.0, t - y));
						ph = h;

						t += h;

						if (res<EPSILON || t>tmax) break;

					}
					res = clamp(res, 0.0, 1.0);
					return res * res*(3.0 - 2.0*res);
				}

				float calcAO(float3 pos, float3 nor)
				{
					float occ = 0.0;
					float sca = 1.0;
					for (int i = 0; i < 5; i++)
					{
						float h = 0.001 + 0.15*float(i) / 4.0;
						float d = getDist(pos + h * nor);
						occ += (h - d)*sca;
						sca *= 0.95;
					}
					return clamp(1.0 - 1.5*occ, 0.0, 1.0);
				}

				fixed4 frag(v2f i) : SV_Target
				{
					float3 ro = i.ro;
					float3 rd = normalize(i.hitPos - ro);
					float4 hit = raymarch(ro, rd);
					float t = hit.w;

					float4 color = float4(0.3, 0.3, 0.3, 1);
					float3 albedo = float3(0, 0.1, 0);
					float3 specular = float3(1.00, 0.70, 0.5);
					float3 p = hit.xyz;
					float3 nor = getNormal(p);

					float height = getHeight(p);
					float ocean = _SeaLevel - height;
					float speInt = 0;
					if (ocean >= 0) {
						albedo = float3(0, 0, 0.1);
						speInt = 12;
					}

					// key light
					float3 lig = normalize(float3(-50, 35, 0));
					float3 hal = normalize(lig - rd);
					float dif = clamp(dot(nor, lig), 0.0, 1.0) * calcSoftshadow(p, lig, 3.0);
					float spe = pow(clamp(dot(nor, hal), 0.0, 1.0), 16.0)* dif * (0.04 + 0.96*pow(clamp(1.0 + dot(hal, rd), 0.0, 1.0), 5.0));

					color.rgb = albedo * 2.0*dif*specular;
					color.rgb += speInt*spe*specular;

					// ambient light
					float occ = calcAO(p, nor);
					float amb = clamp(0.5 + 0.5*nor.y, 0.0, 1.0);
					color.rgb += albedo * amb*occ*float3(0.0, 0.08, 0.1);
					float4 scene = render_scene(ro, rd, lig, color);
					// fog


					// get the atmosphere color
					if (t >= MAX_DIST) color = float4(0, 0, 0, 1);
					color.rgb += calculate_scattering(
						ro,				// the position of the camera
						rd, 					// the camera vector (ray direction of this pixel)
						scene.w, 						// max dist, essentially the scene depth
						scene.xyz,						// scene color, the color of the current pixel being rendered
						lig,						// light direction
						40,						// light intensity, 40 looks nice
						PLANET_POS,						// position of the planet
						PLANET_RADIUS,                  // radius of the planet in meters
						ATMOS_RADIUS,                   // radius of the atmosphere in meters
						RAY_BETA,						// Rayleigh scattering coefficient
						MIE_BETA,                       // Mie scattering coefficient
						ABSORPTION_BETA,                // Absorbtion coefficient
						AMBIENT_BETA,					// ambient scattering, turned off for now. This causes the air to glow a bit when no light reaches it
						G,                          	// Mie preferred scattering direction
						HEIGHT_RAY,                     // Rayleigh scale height
						HEIGHT_MIE,                     // Mie scale height
						HEIGHT_ABSORPTION,				// the height at which the most absorption happens
						ABSORPTION_FALLOFF,				// how fast the absorption falls off from the absorption height 
						PRIMARY_STEPS, 					// steps in the ray direction 
						LIGHT_STEPS 					// steps in the light direction
					);
					
					color.rgb = pow(color, float3(0.4545, 0.4545, 0.4545));
					return color;
				}
				ENDCG
			}
		}
}
