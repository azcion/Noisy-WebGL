const gl = document.getElementById('canvas').getContext('webgl');
initGL();
let _shadersTemplate;
const _shadersCompiled = {};

// Shader attributes with default values
const _attributes = {
	width: 256,
	height: 256,
	offsetx: 0,
	offsety: 0,
	square: false,
	radial: true,
	mass: 150,
	octaves: 6,
	persistence: 0.6,
	frequency: 0.005,
	water: 0.5
};

// Alternative shorter param names
const _params = {
	width: 'w',
	height: 'h',
	offsetx: 'x',
	offsety: 'y',
	square: 'sq',
	radial: 'r',
	mass: 'm',
	octaves: 'o',
	persistence: 'p',
	frequency: 'f',
	water: 'wt'
};

// prettier-ignore
const _gradients = {
	colors: [
		[0.04, 0.32, 0.68],
		[0.23, 0.51, 0.83],
		[0.61, 0.89, 0.99],
		[0.75, 0.65, 0.45],
		[0.31, 0.45, 0.14],
		[0.71, 0.73, 0.47],
		[0.94, 0.93, 0.91]
	],
	positions: [
		0,
		0.15,
		0.20,
		0.24,
		0.33,
		0.70,
		0.80
	]
};

async function initGL() {
	const shaders = await getShaders();
	_shadersTemplate = { ...shaders };
	_shadersCompiled.vertex = createShader(gl, gl.VERTEX_SHADER, shaders.vertex);

	f();
}

function f() {
	const attributes = getAttributes();
	gl.canvas.width = attributes.width;
	gl.canvas.height = attributes.height;
	gl.viewport(0, 0, gl.canvas.width, gl.canvas.height);

	const shaderConfig = {
		attributes: attributes,
		gradients: _gradients
	};

	const fragment = configureShader(_shadersTemplate.fragment, shaderConfig);
	_shadersCompiled.fragment = createShader(gl, gl.FRAGMENT_SHADER, fragment);
	const program = createProgram(gl, _shadersCompiled.vertex, _shadersCompiled.fragment);

	const positionBuffer = gl.createBuffer();
	gl.bindBuffer(gl.ARRAY_BUFFER, positionBuffer);
	gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([-1, -1, 1, -1, 1, 1, -1, 1]), gl.STATIC_DRAW);

	const positionAttributeLocation = gl.getAttribLocation(program, 'Position');
	gl.vertexAttribPointer(positionAttributeLocation, 2, gl.FLOAT, gl.FALSE, 2 * Float32Array.BYTES_PER_ELEMENT, 0);
	gl.enableVertexAttribArray(positionAttributeLocation);

	gl.useProgram(program);
	gl.drawArrays(gl.TRIANGLE_FAN, 0, 4);
	gl.useProgram(null);
}

function configureShader(shader, config) {
	for (const option in config) {
		switch (option) {
			case 'gradients':
				shader = setShaderGradients(shader, config.gradients);
				break;
			case 'attributes':
				shader = setShaderAttributes(shader, config.attributes);
				break;
		}
	}

	return shader;
}

function getAttributes() {
	const params = new URLSearchParams(window.location.search);
	const p = s => params.get(s) || params.get(_params[s]);
	const i = n => parseInt(n);
	const d = n => parseFloat(n);
	const b = s => s && (s === 'true' || s === '1');

	// Width and height
	let w = i(p('width')) || window.innerWidth - 50;
	let h = i(p('height')) || window.innerHeight - 35;
	const square = b(p('square')) || false;

	if (square) {
		// Force square using the shortest side
		if (w < h) {
			h = w;
		} else {
			w = h;
		}
	}

	// Seed
	const x = i(p('offsetx')) || Math.floor(Math.random() * 2 ** 20);
	const y = i(p('offsety')) || Math.floor(Math.random() * 2 ** 20);

	// World generation
	const radial = b(p('radial'));
	const mass = i(p('mass'));
	const octaves = i(p('octaves'));
	const persistence = d(p('persistence'));
	const frequency = d(p('frequency'));

	// Water level
	const water = d(p('water'));

	const attributes = {
		width: w.toFixed(0),
		height: h.toFixed(0),
		offsetx: x.toFixed(0),
		offsety: y.toFixed(0),
		square: square,
		radial: radial,
		mass: formatShaderFloat(mass),
		octaves: formatShaderFloat(octaves),
		persistence: formatShaderFloat(persistence),
		frequency: formatShaderFloat(frequency),
		water: formatShaderFloat(water)
	};

	console.log(joinAttributes(attributes));

	return attributes;
}

function joinAttributes(attributes) {
	let params = [];

	for (const a in attributes) {
		const value = attributes[a];

		if (value == null || value === 'NaN' || value === _attributes[a]) {
			continue;
		}

		params.push(`${_params[a]}=${value}`);
	}

	return '?' + params.join('&');
}

function setShaderAttributes(shader, attributes) {
	for (const a in _attributes) {
		shader = shader.replace(`%${a}%`, getIfValid(attributes[a]) || _attributes[a]);
	}

	return shader;
}

function getIfValid(value) {
	if (value == null || isNaN(value) || value === 'NaN') {
		return false;
	}

	return value.toString();
}

function setShaderGradients(shader, gradients) {
	let colorsCode = '';
	let positionsCode = '';

	for (let i = 0; i < gradients.colors.length; ++i) {
		const c = gradients.colors[i].map(x => formatShaderFloat(x));
		const p = formatShaderFloat(gradients.positions[i]);
		colorsCode += `COL[${i}] = vec4(${c[0]}, ${c[1]}, ${c[2]}, 1.);\n\t`;
		positionsCode += `POS[${i}] = ${p};\n\t`;
	}

	shader = shader.replace(/%ncolors%/, gradients.colors.length);
	shader = shader.replace(/%colors%/, colorsCode);
	shader = shader.replace(/%positions%/, positionsCode);

	return shader;
}

function formatShaderFloat(number) {
	let f = number.toString();

	// Number is an integer
	if (!f.includes('.')) {
		return f + '.';
	}

	const components = f.split('.');

	// Number doesn't start with a zero
	if (components[0] !== '0') {
		return f;
	}

	// Number starts with a zero
	return '.' + components[1];
}

async function getShaders() {
	const shaderFiles = ['vertex', 'fragment'];
	const shaders = {};

	for (const file of shaderFiles) {
		shaders[file] = await getFile(`glsl/${file}.glsl`);
	}

	return shaders;
}

async function getFile(path) {
	return (await fetch(path, { method: 'GET' })).text();
}

function createShader(gl, type, source) {
	const shader = gl.createShader(type);
	gl.shaderSource(shader, source);
	gl.compileShader(shader);
	const success = gl.getShaderParameter(shader, gl.COMPILE_STATUS);

	if (success) {
		return shader;
	}

	console.log(gl.getShaderInfoLog(shader));
	gl.deleteShader(shader);
}

function createProgram(gl, vertexShader, fragmentShader) {
	const program = gl.createProgram();
	gl.attachShader(program, vertexShader);
	gl.attachShader(program, fragmentShader);
	gl.linkProgram(program);
	const success = gl.getProgramParameter(program, gl.LINK_STATUS);

	if (success) {
		return program;
	}

	console.log(gl.getProgramInfoLog(program));
	gl.deleteProgram(program);
}
