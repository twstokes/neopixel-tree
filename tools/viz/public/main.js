import * as THREE from "three";
import { OrbitControls } from "three/examples/jsm/controls/OrbitControls";
import { lightPositions, PIXEL_COUNT } from "./positions.js";

const container = document.getElementById("scene");
const statusEl = document.getElementById("status");
const commandEl = document.getElementById("command");
let starMesh = null;

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
  new THREE.CircleGeometry(0.75, 64),
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
  const isStarRing = idx >= 90;
  const size = isStarRing ? 0.09 : 0.08;
  const geo = new THREE.PlaneGeometry(size, size);
  const mat = new THREE.MeshStandardMaterial({
    color: 0x111111,
    emissive: 0x000000,
    emissiveIntensity: 1,
    roughness: 0.35,
    metalness: 0.2,
    side: THREE.DoubleSide,
  });
  const mesh = new THREE.Mesh(geo, mat);
  mesh.position.set(pos.x, pos.y, pos.z);

  if (isStarRing) {
    mesh.rotation.x = -Math.PI / 2; // point upward
  } else {
    const outward = new THREE.Vector3(pos.x, 0, pos.z).normalize();
    if (outward.lengthSq() < 1e-6) outward.set(0, 0, 1);
    const target = outward.clone().add(mesh.position);
    mesh.lookAt(target); // orient normal outward from the tree
  }

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
  updateGlitter();
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
  const radius = 0.8; // pull cone inward so pixels sit outside the surface

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

  const starOffset = 0.2;
  starMesh = createStarMesh();
  starMesh.position.y = height + starOffset;
  starMesh.rotation.z = Math.PI;
  group.add(starMesh);

  const starStem = new THREE.Mesh(
    new THREE.CylinderGeometry(0.05, 0.07, 0.2, 8),
    new THREE.MeshStandardMaterial({
      color: 0xb8c0cc,
      roughness: 0.25,
      metalness: 0.5,
    }),
  );
  starStem.position.y = height + 0;
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
    color: 0xdfe5ef,
    emissive: 0x2a303a,
    roughness: 0.05, // smoother surface for sharper reflections
    metalness: 0.95, // highly metallic for strong reflections
    envMapIntensity: 1.25,
    emissiveIntensity: 1.2,
  });
  return new THREE.Mesh(geo, mat);
}

function updateGlitter() {
  if (!starMesh) return;
  const t = performance.now() * 0.002;
  const sparkle = 0.7 + 0.25 * Math.sin(t * 1.3) + 0.15 * Math.random();
  starMesh.material.emissiveIntensity = 1.1 + sparkle * 0.6;
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
    8: "Holiday Rotation",
    253: "Reset Info",
    254: "Uptime",
    255: "Readback",
  };
  const name = labels[command] ?? "Idle";
  return repeat ? `${name} (repeating)` : name;
}
