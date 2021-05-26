precision mediump float;

// Set by JS
#define WIDTH %width%
#define HEIGHT %height%
#define SEED %seed%

#define M289 0.00346020761 // 1/289
#define K 0.142857142857 // 1/7
#define Ko 0.428571428571 // 1/2-K/2

vec3 mod289(vec3 x) {
	return x - floor(x * M289) * 289.0;
}

vec2 mod289(vec2 x) {
	return x - floor(x * M289) * 289.0;
}

vec3 mod7(vec3 x) {
	return x - floor(x * K) * 7.0;
}

vec3 permute(vec3 x) {
	return mod289((34.0 * x + 1.0) * x);
}

// Cellular noise, standard 3x3 search window for good F1 and F2 values
float cellular(vec2 P) {
	vec2 Pi = mod289(floor(P));
 	vec2 Pf = fract(P);
	vec3 oi = vec3(-1.0, 0.0, 1.0);
	vec3 of = vec3(-0.5, 0.5, 1.5);
	vec3 px = permute(Pi.x + oi);
	vec3 p = permute(px.x + Pi.y + oi); // p11, p12, p13
	vec3 ox = fract(p*K) - Ko;
	vec3 oy = mod7(floor(p*K))*K - Ko;
	vec3 dx = Pf.x + 0.5 + ox;
	vec3 dy = Pf.y - of + oy;
	vec3 d1 = dx * dx + dy * dy; // d11, d12 and d13, squared
	p = permute(px.y + Pi.y + oi); // p21, p22, p23
	ox = fract(p*K) - Ko;
	oy = mod7(floor(p*K))*K - Ko;
	dx = Pf.x - 0.5 + ox;
	dy = Pf.y - of + oy;
	vec3 d2 = dx * dx + dy * dy; // d21, d22 and d23, squared
	p = permute(px.z + Pi.y + oi); // p31, p32, p33
	ox = fract(p*K) - Ko;
	oy = mod7(floor(p*K))*K - Ko;
	dx = Pf.x - 1.5 + ox;
	dy = Pf.y - of + oy;
	vec3 d3 = dx * dx + dy * dy; // d31, d32 and d33, squared
	// Sort out the two smallest distances (F1, F2)
	vec3 d1a = min(d1, d2);
	d2 = max(d1, d2); // Swap to keep candidates for F2
	d2 = min(d2, d3); // neither F1 nor F2 are now in d3
	d1 = min(d1a, d2); // F1 is now in d1
	d1.xy = (d1.x < d1.y) ? d1.xy : d1.yx; // Swap if smaller
	d1.xz = (d1.x < d1.z) ? d1.xz : d1.zx; // F1 is in d1.x
	//return sqrt(d1.x);
	return max(d1.x, 0.0001); // Cap min at 0.0001
}

float snoise(vec2 v) {
	const vec4 C = vec4(
		0.211324865405187,  // (3.0-sqrt(3.0))/6.0
		0.366025403784439,  // 0.5*(sqrt(3.0)-1.0)
		-0.577350269189626, // -1.0 + 2.0 * C.x
		0.024390243902439); // 1.0 / 41.0
	// First corner
	vec2 i = floor(v + dot(v, C.yy) );
	vec2 x0 = v - i + dot(i, C.xx);

	// Other corners
	vec2 i1;
	i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
	vec4 x12 = x0.xyxy + C.xxzz;
	x12.xy -= i1;

	// Permutations
	i = mod289(i); // Avoid truncation effects in permutation
	vec3 p = permute(
		permute(i.y + vec3(0.0, i1.y, 1.0))
		+ i.x + vec3(0.0, i1.x, 1.0));

	vec3 m = max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy), dot(x12.zw,x12.zw)), 0.0);
	m = m*m;
	m = m*m;

	// Gradients: 41 points uniformly over a line, mapped onto a diamond.
	// The ring size 17*17 = 289 is close to a multiple of 41 (41*7 = 287)

	vec3 x = 2.0 * fract(p * C.www) - 1.0;
	vec3 h = abs(x) - 0.5;
	vec3 ox = floor(x + 0.5);
	vec3 a0 = x - ox;

	// Normalise gradients implicitly by scaling m
	// Approximation of: m *= inversesqrt( a0*a0 + h*h );
	m *= 1.79284291400159 - 0.85373472095314 * (a0*a0 + h*h);

	// Compute final noise value at P
	vec3 g;
	g.x = a0.x * x0.x + h.x * x0.y;
	g.yz = a0.yz * x12.xz + h.yz * x12.yw;
	return 130.0 * dot(m, g);
}

float sumOctaves(vec2 uv, float persistence, float scale, float low, float high) {
	float maxAmp = 0.0;
	float amp = 1.0;
	float freq = scale;
	float noise = 0.0;

	for (int i = 0; i < 6; ++i) {
		noise += snoise(uv * freq) * amp;
		maxAmp += amp;
		amp *= persistence;
		freq *= 2.5;
	}

	noise /= maxAmp;
	noise = noise * (high - low) / 2.0 + (high + low) / 2.0;
	return noise;
}

void main() {
	vec2 uv = gl_FragCoord.xy;
	float xr = uv.x / WIDTH;
	float yr = uv.y / HEIGHT;
	uv += SEED;
	float d = 1.125;
	float f = (1.0 - xr * xr + xr - d) + (1.0 - yr * yr + yr - d);
	f *= 7.5;
	f = max(f, 0.0);
	float v = 0.0;

	if (f > 0.0) {
		float a = 1.0 - cellular(uv.xy / 128.0);
		float b = sumOctaves(uv.xy, 0.6, 0.005, 0.0, 1.0);
		v = (a * 2.0) * b - 0.5;
	}

	v = v * f - 0.6;
	v = clamp(v, 0.0, 1.0);
	vec4 color = vec4(vec3(v), 1.0);
	//color = mix(vec4(0.5, 0.5, 0.5, 1.0), vec4(1.0, 1.0, 1.0, 1.0), color);
	gl_FragColor = color;
}