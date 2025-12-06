import * as THREE from "three";
import { OrbitControls } from "three/examples/jsm/controls/OrbitControls";
import { lightPositions, PIXEL_COUNT } from "./positions.js";

const container = document.getElementById("scene");
const statusEl = document.getElementById("status");
const commandEl = document.getElementById("command");

const renderer = new THREE.WebGLRenderer({ antialias: true });
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.setPixelRatio(window.devicePixelRatio || 1);
renderer.setClearColor(0x04080f, 1);
container.appendChild(renderer.domElement);

const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(
  50,
  window.innerWidth / window.innerHeight,
  0.1,
  20,
);
camera.position.set(0, 1.6, 4.5);

const controls = new OrbitControls(camera, renderer.domElement);
controls.target.set(0, 1.2, 0);
controls.enableDamping = true;

scene.add(new THREE.AmbientLight(0xffffff, 0.6));
const keyLight = new THREE.DirectionalLight(0xffffff, 0.8);
keyLight.position.set(3, 4, 2);
scene.add(keyLight);

const rimLight = new THREE.PointLight(0x88b4ff, 0.4, 8);
rimLight.position.set(-2, 2, -1);
scene.add(rimLight);

const ground = new THREE.Mesh(
  new THREE.CircleGeometry(3, 64),
  new THREE.MeshStandardMaterial({
    color: 0x082418,
    roughness: 0.9,
    metalness: 0.05,
    side: THREE.DoubleSide,
  }),
);
ground.rotation.x = -Math.PI / 2;
scene.add(ground);

const tree = createTree();
scene.add(tree);

const pixelMeshes = lightPositions.map((pos, idx) => {
  const geo = new THREE.SphereGeometry(0.04, 16, 16);
  const mat = new THREE.MeshStandardMaterial({
    color: 0x111111,
    emissive: 0x000000,
    emissiveIntensity: 1,
    roughness: 0.4,
    metalness: 0.1,
  });
  const mesh = new THREE.Mesh(geo, mat);
  mesh.position.set(pos.x, pos.y, pos.z);
  mesh.userData.index = idx;
  scene.add(mesh);
  return mesh;
});

const eventSource = new EventSource("/events");
eventSource.onmessage = (event) => {
  const payload = JSON.parse(event.data);
  updatePixels(payload.pixels);
  statusEl.textContent = `UDP port 8733 · Brightness ${payload.brightness}`;
  commandEl.textContent = describeCommand(payload.command, payload.repeat);
};

eventSource.onerror = () => {
  statusEl.textContent = "Event stream disconnected";
};

window.addEventListener("resize", onResize);
onResize();
animate();

function animate() {
  requestAnimationFrame(animate);
  controls.update();
  renderer.render(scene, camera);
}

function onResize() {
  const width = window.innerWidth;
  const height = window.innerHeight;
  camera.aspect = width / height;
  camera.updateProjectionMatrix();
  renderer.setSize(width, height);
}

function updatePixels(pixels) {
  if (!pixels || pixels.length !== PIXEL_COUNT) return;
  for (let i = 0; i < PIXEL_COUNT; i++) {
    const c = pixels[i];
    const mesh = pixelMeshes[i];
    if (!mesh || !c) continue;
    const color = new THREE.Color(c.r / 255, c.g / 255, c.b / 255);
    mesh.material.color.copy(color);
    mesh.material.emissive.copy(color);
  }
}

function createTree() {
  const group = new THREE.Group();
  const height = 2.4;
  const radius = 0.95;

  const coneGeo = new THREE.ConeGeometry(radius, height, 48, 1, true);
  const coneMat = new THREE.MeshStandardMaterial({
    color: 0x0f392a,
    transparent: true,
    opacity: 0.65,
    roughness: 0.6,
    metalness: 0.05,
    side: THREE.DoubleSide,
  });
  const cone = new THREE.Mesh(coneGeo, coneMat);
  cone.position.y = height / 2;
  group.add(cone);

  const trunk = new THREE.Mesh(
    new THREE.CylinderGeometry(0.13, 0.18, 0.4, 16),
    new THREE.MeshStandardMaterial({ color: 0x4b2f1c, roughness: 0.8 }),
  );
  trunk.position.y = 0.2;
  group.add(trunk);

  const starOffset = 0.3;
  const star = createStarMesh();
  star.position.y = height + starOffset * 1.5; // raise star 50% higher
  star.rotation.z = Math.PI;
  group.add(star);

  const starStem = new THREE.Mesh(
    new THREE.CylinderGeometry(0.05, 0.07, 0.2, 8),
    new THREE.MeshStandardMaterial({
      color: 0xb8c0cc,
      roughness: 0.25,
      metalness: 0.5,
    }),
  );
  starStem.position.y = height + 0.2;
  group.add(starStem);

  return group;
}

function createStarMesh() {
  const outer = 0.3;
  const inner = 0.12;
  const shape = new THREE.Shape();
  for (let i = 0; i < 10; i++) {
    const radius = i % 2 === 0 ? outer : inner;
    const angle = (i / 10) * Math.PI * 2 - Math.PI / 2;
    const x = Math.cos(angle) * radius;
    const y = Math.sin(angle) * radius;
    if (i === 0) shape.moveTo(x, y);
    else shape.lineTo(x, y);
  }
  shape.closePath();

  const geo = new THREE.ExtrudeGeometry(shape, {
    steps: 1,
    depth: 0.08,
    bevelEnabled: false,
  });
  const mat = new THREE.MeshStandardMaterial({
    color: 0xd8dde6,
    emissive: 0x1e222a,
    roughness: 0.12,
    metalness: 0.65,
  });
  return new THREE.Mesh(geo, mat);
}

function describeCommand(command, repeat) {
  const labels = {
    0: "Off",
    1: "Brightness",
    2: "Pixel",
    3: "Fill",
    4: "Fill Pattern",
    5: "Rainbow",
    6: "Rainbow Cycle",
    7: "Theater Chase",
    253: "Reset Info",
    254: "Uptime",
    255: "Readback",
  };
  const name = labels[command] ?? "Idle";
  return repeat ? `${name} (repeating)` : name;
}
