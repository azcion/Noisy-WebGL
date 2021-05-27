precision highp float;

// Set by JS
#define WIDTH %width%.
#define HEIGHT %height%.
#define OFFSETX %offsetx%.
#define OFFSETY %offsety%.
#define RADIAL %radial%
#define MASS %mass%.
#define OCTAVES %octaves%
#define PERSISTENCE %persistence%
#define FREQUENCY %frequency%
#define WATER_LEVEL %water%

#define M289 .00346020761 // 1 / 289
#define K .142857142857 // 1 / 7
#define Ko .428571428571 // 1 / 2 - K / 2

vec3 mod289(vec3 x) {
	return x - floor(x * M289) * 289.;
}

vec2 mod289(vec2 x) {
	return x - floor(x * M289) * 289.;
}

vec3 mod7(vec3 x) {
	return x - floor(x * K) * 7.;
}

vec3 permute(vec3 x) {
	return mod289((34. * x + 1.) * x);
}

float cellular(vec2 P) {
	vec2 Pi = mod289(floor(P));
 	vec2 Pf = fract(P);
	vec3 oi = vec3(-1., 0, 1.);
	vec3 of = vec3(-.5, .5, 1.5);
	vec3 px = permute(Pi.x + oi);
	vec3 p = permute(px.x + Pi.y + oi);
	vec3 ox = fract(p*K) - Ko;
	vec3 oy = mod7(floor(p*K))*K - Ko;
	vec3 dx = Pf.x + .5 + ox;
	vec3 dy = Pf.y - of + oy;
	vec3 d1 = dx * dx + dy * dy;
	p = permute(px.y + Pi.y + oi);
	ox = fract(p*K) - Ko;
	oy = mod7(floor(p*K))*K - Ko;
	dx = Pf.x - .5 + ox;
	dy = Pf.y - of + oy;
	vec3 d2 = dx * dx + dy * dy;
	p = permute(px.z + Pi.y + oi);
	ox = fract(p*K) - Ko;
	oy = mod7(floor(p*K))*K - Ko;
	dx = Pf.x - 1.5 + ox;
	dy = Pf.y - of + oy;
	vec3 d3 = dx * dx + dy * dy;
	vec3 d1a = min(d1, d2);
	d2 = max(d1, d2);
	d2 = min(d2, d3);
	d1 = min(d1a, d2);
	d1.xy = (d1.x < d1.y) ? d1.xy : d1.yx;
	d1.xz = (d1.x < d1.z) ? d1.xz : d1.zx;
	return max(d1.x, .0001); // Cap min at .0001
}

float snoise(vec2 v) {
	const vec4 C = vec4(
		.211324865405187,  // (3 - sqrt(3)) / 6
		.366025403784439,  // .5 * (sqrt(3) -1)
		-.577350269189626, // -1 + 2 * C.x
		.024390243902439); // 1 / 41
	vec2 i = floor(v + dot(v, C.yy) );
	vec2 x0 = v - i + dot(i, C.xx);
	vec2 i1;
	i1 = (x0.x > x0.y) ? vec2(1., 0) : vec2(0, 1.);
	vec4 x12 = x0.xyxy + C.xxzz;
	x12.xy -= i1;
	i = mod289(i);
	vec3 p = permute(
		permute(i.y + vec3(0, i1.y, 1.))
		+ i.x + vec3(0, i1.x, 1.));
	vec3 m = max(.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy), dot(x12.zw,x12.zw)), 0.);
	m = m*m;
	m = m*m;
	vec3 x = 2. * fract(p * C.www) - 1.;
	vec3 h = abs(x) - .5;
	vec3 ox = floor(x + .5);
	vec3 a0 = x - ox;
	m *= 1.79284291400159 - .85373472095314 * (a0*a0 + h*h);
	vec3 g;
	g.x = a0.x * x0.x + h.x * x0.y;
	g.yz = a0.yz * x12.xz + h.yz * x12.yw;
	return 130. * dot(m, g);
}

float sumOctaves(vec2 uv, float persistence, float scale) {
	float maxAmp = 0.;
	float amp = 1.;
	float freq = scale;
	float noise = 0.;

	for (int i = 0; i < OCTAVES; ++i) {
		noise += snoise(uv * freq) * amp;
		maxAmp += amp;
		amp *= persistence;
		freq *= 2.5;
	}

	noise /= maxAmp;
	noise = noise * .5 + .5;
	return noise;
}

vec4 getColor(float v) {
	#define N %ncolors%
	vec4 COL[N];
	%colors%

	float POS[N];
	%positions%

	if (v <= POS[0]) {
		return COL[0];
	}

	for (int i = 1; i < N; ++i) {
		if (v <= POS[i]) {
			float s = (v - POS[i - 1]) / (POS[i] - POS[i - 1]);
			return mix(COL[i - 1], COL[i], s);
		}
	}

	return COL[N - 1];
}

void main() {
	vec2 uv = gl_FragCoord.xy;
	float xr = uv.x / WIDTH;
	float yr = uv.y / HEIGHT;
	uv = vec2(uv.x + OFFSETX, uv.y + OFFSETY);
	float d = 1.125;
	float f;
	
	if (RADIAL) {
		f = (1. - xr * xr + xr - d) + (1. - yr * yr + yr - d);
	} else {
		f = .25;
	}
	
	f *= 7.5;
	f = clamp(f, 0., 1.);
	float v = 0.;

	if (f > 0.) {
		float a = 1. - cellular(uv.xy / MASS);
		float b = sumOctaves(uv.xy, PERSISTENCE, FREQUENCY);
		v = (a * 2.) * b - .5;
	}

	v = v * f - .6;
	v += 1. - WATER_LEVEL;
	v = clamp(v, 0., 1.);

	gl_FragColor = getColor(v);
}