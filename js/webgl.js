const gl = document.getElementById('canvas').getContext('webgl');
initGL();
let _shaders;

async function initGL() {
	const shaders = await getShaders();
	_shaders = { ...shaders };

	f();
}

function f() {
	let w = window.innerWidth - 50;
	let h = window.innerHeight - 35;

	if (w < h) {
		h = w;
	} else {
		w = h;
	}

	gl.canvas.width = w;
	gl.canvas.height = h;
	gl.viewport(0, 0, gl.canvas.width, gl.canvas.height);

	let shaders = { ..._shaders };
	shaders.fragment = setShaderAttributes(shaders.fragment, {
		width: `${canvas.width}.0`,
		height: `${canvas.height}.0`,
		seed: `${Math.floor(Math.random() * 2 ** 20)}.0`
	});

	const vertexShader = createShader(gl, gl.VERTEX_SHADER, shaders.vertex);
	const fragmentShader = createShader(gl, gl.FRAGMENT_SHADER, shaders.fragment);
	const program = createProgram(gl, vertexShader, fragmentShader);

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

function setShaderAttributes(shader, attr) {
	shader = shader.replace(/%width%/, attr.width || '256.0');
	shader = shader.replace(/%height%/, attr.height || '256.0');
	shader = shader.replace(/%seed%/, attr.seed || '0.0');

	return shader;
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
