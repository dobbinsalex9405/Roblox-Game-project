// Loop Lab design viewer: browse every design like folders in File Explorer,
// search them, and look at each one in 3D.
//
// Built into ../dist/viewer.js (one classic script, so the page works when
// opened straight from disk). See ../../README.md.

import * as THREE from "three";
import { OrbitControls } from "three/examples/jsm/controls/OrbitControls.js";
import { DRACOLoader } from "three/examples/jsm/loaders/DRACOLoader.js";
import { GLTFLoader } from "three/examples/jsm/loaders/GLTFLoader.js";
import { RoomEnvironment } from "three/examples/jsm/environments/RoomEnvironment.js";

const catalog = window.DESIGN_CATALOG;
const $ = (sel) => document.querySelector(sel);

const TIER_COLORS = {
  Common: "#8a94a6",
  Uncommon: "#2fa84f",
  Rare: "#2f7de1",
  "Ultra Rare": "#13a8b8",
  Epic: "#8e44d6",
  Legendary: "#f08c00",
  Godly: "#e0245e",
};

// A design added in the last three days gets a "New" badge.
const NEW_FOR_MS = 3 * 24 * 3600 * 1000;

function el(tag, attrs = {}, ...children) {
  const node = document.createElement(tag);
  for (const [k, v] of Object.entries(attrs)) {
    if (v === undefined || v === null || v === false) continue;
    if (k === "class") node.className = v;
    else if (k.startsWith("on")) node.addEventListener(k.slice(2), v);
    else if (k === "text") node.textContent = v;
    else node.setAttribute(k, v === true ? "" : v);
  }
  for (const c of children.flat()) {
    if (c === null || c === undefined || c === false) continue;
    node.append(c instanceof Node ? c : document.createTextNode(String(c)));
  }
  return node;
}

function storage(key, value) {
  try {
    if (value === undefined) return localStorage.getItem(key);
    localStorage.setItem(key, value);
  } catch {
    return null;
  }
  return null;
}

/* ------------------------------------------------------------------------ */
/* The folder tree, from each design's path                                 */
/* ------------------------------------------------------------------------ */

const keyOf = (parts) => parts.map((p) => p.toLowerCase()).join("/");

function makeFolder(name, path) {
  return { name, path, folders: new Map(), items: [], total: 0 };
}

const root = makeFolder("Designs", []);
const items = catalog ? catalog.items : [];
for (const item of items) {
  let folder = root;
  folder.total++;
  item.path.forEach((part, i) => {
    const k = part.toLowerCase();
    if (!folder.folders.has(k)) folder.folders.set(k, makeFolder(part, item.path.slice(0, i + 1)));
    folder = folder.folders.get(k);
    folder.total++;
  });
  folder.items.push(item);
  item.folder = folder;
  item.updated = Math.max(0, ...item.versions.map((v) => (v.updated ? Date.parse(v.updated) : 0)));
  item.haystack = [item.name, ...item.path, item.game, item.tier, item.where]
    .filter(Boolean)
    .join(" ")
    .toLowerCase();
}

function sortedFolders(folder) {
  const order = catalog?.folderOrder ?? {};
  return [...folder.folders.values()].sort((a, b) => {
    const oa = order[keyOf(a.path)] ?? [999, a.name.toLowerCase()];
    const ob = order[keyOf(b.path)] ?? [999, b.name.toLowerCase()];
    return oa[0] - ob[0] || oa[1].localeCompare(ob[1]);
  });
}

function sortedItems(list) {
  return [...list].sort((a, b) => a.name.localeCompare(b.name, undefined, { numeric: true }));
}

function folderAt(path) {
  let folder = root;
  for (const part of path) {
    folder = folder.folders.get(part.toLowerCase());
    if (!folder) return null;
  }
  return folder;
}

function itemAt(path) {
  if (path.length === 0) return null;
  const folder = folderAt(path.slice(0, -1));
  if (!folder) return null;
  const name = path[path.length - 1].toLowerCase();
  return folder.items.find((it) => it.name.toLowerCase() === name) ?? null;
}

/* ------------------------------------------------------------------------ */
/* Turning designs into 3D                                                  */
/* ------------------------------------------------------------------------ */

const geometries = {
  block: new THREE.BoxGeometry(1, 1, 1),
  ball: new THREE.SphereGeometry(0.5, 24, 16),
  // Roblox cylinders run along X.
  cylinder: new THREE.CylinderGeometry(0.5, 0.5, 1, 24).rotateZ(Math.PI / 2),
  wedge: wedgeGeometry(),
};
geometries.cornerwedge = geometries.wedge;
geometries.mesh = geometries.block;

// A Roblox wedge: full bottom and back (+Z), sloping down to the front (-Z).
function wedgeGeometry() {
  const g = new THREE.BufferGeometry();
  const v = [
    [-0.5, -0.5, -0.5], [0.5, -0.5, -0.5], [0.5, -0.5, 0.5], [-0.5, -0.5, 0.5],
    [-0.5, 0.5, 0.5], [0.5, 0.5, 0.5],
  ];
  const faces = [
    [0, 1, 2], [0, 2, 3], // bottom
    [3, 2, 5], [3, 5, 4], // back
    [0, 4, 5], [0, 5, 1], // slope
    [0, 3, 4], // left
    [1, 5, 2], // right
  ];
  const pos = [];
  for (const f of faces) for (const i of f) pos.push(...v[i]);
  g.setAttribute("position", new THREE.Float32BufferAttribute(pos, 3));
  g.computeVertexNormals();
  return g;
}

const materials = new Map();
function materialFor(hex, material, transparency) {
  const key = `${hex}|${material}|${transparency}`;
  if (materials.has(key)) return materials.get(key);
  const color = new THREE.Color(`#${hex}`);
  const m = new THREE.MeshStandardMaterial({ color, roughness: 0.75, metalness: 0 });
  if (material === "Neon") {
    m.emissive = color.clone();
    m.emissiveIntensity = 1.1;
  } else if (material === "Metal" || material === "DiamondPlate" || material === "Foil") {
    m.metalness = 0.55;
    m.roughness = 0.4;
  } else if (material === "Glass") {
    m.roughness = 0.1;
    m.transparent = true;
    m.opacity = Math.min(1 - transparency, 0.6);
  } else if (material === "ForceField") {
    m.transparent = true;
    m.opacity = 0.35;
    m.emissive = color.clone();
    m.emissiveIntensity = 0.5;
  } else if (["Grass", "Ground", "Sand", "Mud", "Fabric", "Rock", "Slate", "Concrete", "Asphalt", "Brick"].includes(material)) {
    m.roughness = 0.95;
  } else if (material === "SmoothPlastic") {
    m.roughness = 0.6;
  }
  if (transparency > 0 && material !== "Glass") {
    m.transparent = true;
    m.opacity = 1 - transparency;
  }
  if (m.transparent) m.depthWrite = false;
  materials.set(key, m);
  return m;
}

// One part: [shape, x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22,
// sx, sy, sz, "RRGGBB", transparency, material].
function partsToObject(parts) {
  const group = new THREE.Group();
  const matrix = new THREE.Matrix4();
  const scale = new THREE.Matrix4();
  for (const p of parts) {
    const shape = geometries[p[0]] ? p[0] : "block";
    let sx = p[13];
    let sy = p[14];
    let sz = p[15];
    if (shape === "ball") {
      const d = Math.min(sx, sy, sz);
      sx = sy = sz = d;
    } else if (shape === "cylinder") {
      const d = Math.min(sy, sz);
      sy = sz = d;
    }
    const mesh = new THREE.Mesh(geometries[shape], materialFor(p[16], p[18], p[17]));
    matrix.set(p[4], p[5], p[6], p[1], p[7], p[8], p[9], p[2], p[10], p[11], p[12], p[3], 0, 0, 0, 1);
    scale.makeScale(sx, sy, sz);
    mesh.matrixAutoUpdate = false;
    mesh.matrix.multiplyMatrices(matrix, scale);
    mesh.castShadow = p[17] < 0.5;
    mesh.receiveShadow = true;
    group.add(mesh);
  }
  return group;
}

// Each .glb arrives as a script that calls this with its bytes (base64).
const glbBytes = new Map();
const glbWaiting = new Map();
window.__designData = (hash, base64) => {
  const raw = atob(base64);
  const bytes = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
  glbBytes.set(hash, bytes.buffer);
  const waiting = glbWaiting.get(hash);
  if (waiting) {
    glbWaiting.delete(hash);
    waiting.resolve(bytes.buffer);
  }
};

function loadGlbBytes(version) {
  if (glbBytes.has(version.hash)) return Promise.resolve(glbBytes.get(version.hash));
  if (glbWaiting.has(version.hash)) return glbWaiting.get(version.hash).promise;
  let resolve;
  let reject;
  const promise = new Promise((res, rej) => {
    resolve = res;
    reject = rej;
  });
  glbWaiting.set(version.hash, { promise, resolve });
  const script = el("script", { src: version.file });
  script.onerror = () => {
    glbWaiting.delete(version.hash);
    reject(new Error(`The model file ${version.file} is missing. Rebuild the viewer.`));
  };
  document.head.append(script);
  return promise;
}

const gltfLoader = new GLTFLoader();

// Draco-compressed .glb files: the decoder comes from app/draco.js, loaded
// the first time a model needs it (a page opened from disk cannot fetch the
// decoder files the usual way).
let dracoLibrary = null;
function loadDracoLibrary() {
  if (!dracoLibrary) {
    dracoLibrary = new Promise((resolve, reject) => {
      const script = el("script", { src: "app/draco.js" });
      script.onload = () => resolve(window.__dracoLibrary);
      script.onerror = () => reject(new Error("The Draco decoder (app/draco.js) is missing. Rebuild the viewer."));
      document.head.append(script);
    });
  }
  return dracoLibrary;
}
const dracoLoader = new DRACOLoader();
dracoLoader._loadLibrary = (url) =>
  loadDracoLibrary().then((lib) => {
    if (!url.endsWith(".wasm")) return lib.wrapper;
    const raw = atob(lib.wasm);
    const bytes = new Uint8Array(raw.length);
    for (let i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
    return bytes.buffer;
  });
gltfLoader.setDRACOLoader(dracoLoader);

// Far-away level-of-detail copies inside a .glb ("Bunny_body_lod1") are for
// the game, not for looking at: hide them or every design shows twice.
const LOD = /_lod\d+$/i;

async function loadVersion(version) {
  if (version.kind === "parts") {
    return { object: partsToObject(version.parts), clips: [] };
  }
  const bytes = await loadGlbBytes(version);
  const gltf = await new Promise((res, rej) => gltfLoader.parse(bytes, "", res, rej));
  const object = gltf.scene;
  object.traverse((o) => {
    if (LOD.test(o.name)) o.visible = false;
    if (o.isMesh) {
      o.castShadow = true;
      o.receiveShadow = true;
    }
  });
  return { object, clips: gltf.animations ?? [] };
}

function visibleBox(object) {
  const box = new THREE.Box3();
  object.updateMatrixWorld(true);
  object.traverse((o) => {
    if (!o.isMesh) return;
    let shown = true;
    for (let p = o; p; p = p.parent) if (!p.visible) shown = false;
    if (shown) box.expandByObject(o);
  });
  if (box.isEmpty()) box.setFromObject(object);
  return box;
}

// The side players see first. Roblox models face -Z, and the studio's .glb
// files are made for Roblox, so they face -Z too.
function frontOf() {
  return -1;
}

// Puts the camera in front of the design, a little to the side and above,
// just far enough back that every corner of its box is in view.
function frame(camera, controls, box, front) {
  const size = box.getSize(new THREE.Vector3());
  const centre = box.getCenter(new THREE.Vector3());
  const radius = Math.max(size.length() / 2, 0.5);
  const dir = new THREE.Vector3(0.62, 0.48, 0.66 * front).normalize();
  const right = new THREE.Vector3().crossVectors(new THREE.Vector3(0, 1, 0), dir).normalize();
  const up = new THREE.Vector3().crossVectors(dir, right).normalize();
  const tanV = Math.tan(THREE.MathUtils.degToRad(camera.fov) / 2);
  const tanH = tanV * camera.aspect;
  let distance = 0;
  const corner = new THREE.Vector3();
  for (let i = 0; i < 8; i++) {
    corner.set(i & 1 ? box.max.x : box.min.x, i & 2 ? box.max.y : box.min.y, i & 4 ? box.max.z : box.min.z);
    corner.sub(centre);
    const toward = corner.dot(dir);
    distance = Math.max(
      distance,
      toward + Math.abs(corner.dot(right)) / tanH,
      toward + Math.abs(corner.dot(up)) / tanV,
    );
  }
  distance = Math.max(distance * 1.12, radius * 0.6);
  camera.position.copy(centre).addScaledVector(dir, distance);
  camera.near = Math.max(distance / 500, 0.01);
  camera.far = distance * 50;
  camera.updateProjectionMatrix();
  camera.lookAt(centre);
  if (controls) {
    controls.target.copy(centre);
    controls.minDistance = radius * 0.15;
    controls.maxDistance = distance * 6;
    controls.update();
  }
}

function makeLights(scene) {
  scene.add(new THREE.HemisphereLight(0xffffff, 0x8a93a6, 1.1));
  const sun = new THREE.DirectionalLight(0xffffff, 2.2);
  sun.castShadow = true;
  sun.shadow.mapSize.set(2048, 2048);
  sun.shadow.bias = -0.0004;
  sun.shadow.normalBias = 0.02;
  scene.add(sun);
  scene.add(sun.target);
  return sun;
}

function placeSun(sun, box) {
  const size = box.getSize(new THREE.Vector3());
  const centre = box.getCenter(new THREE.Vector3());
  const r = Math.max(size.length() / 2, 1);
  sun.position.copy(centre).add(new THREE.Vector3(0.45, 1.6, -0.55).normalize().multiplyScalar(r * 3));
  sun.target.position.copy(centre);
  const cam = sun.shadow.camera;
  cam.left = cam.bottom = -r * 1.3;
  cam.right = cam.top = r * 1.3;
  cam.near = r * 0.5;
  cam.far = r * 6;
  cam.updateProjectionMatrix();
}

// Grid squares: 1 stud for small designs, more for big ones.
function gridStep(span) {
  for (const step of [1, 2, 4, 8, 16, 32, 64]) if (span / step <= 40) return step;
  return 128;
}

function makeGround(box) {
  const size = box.getSize(new THREE.Vector3());
  const centre = box.getCenter(new THREE.Vector3());
  const span = Math.max(size.x, size.z) * 1.6 + 2;
  const step = gridStep(span);
  const cells = Math.max(2, Math.ceil(span / step / 2) * 2);
  const group = new THREE.Group();
  const shadow = new THREE.Mesh(
    new THREE.PlaneGeometry(cells * step * 2, cells * step * 2).rotateX(-Math.PI / 2),
    new THREE.ShadowMaterial({ opacity: 0.18 }),
  );
  shadow.receiveShadow = true;
  group.add(shadow);
  const grid = new THREE.GridHelper(cells * step, cells, 0x8090b0, 0x8090b0);
  grid.material.transparent = true;
  grid.material.opacity = 0.22;
  grid.material.depthWrite = false;
  group.add(grid);
  group.position.set(centre.x, box.min.y - 0.002, centre.z);
  return { group, step };
}

/* ------------------------------------------------------------------------ */
/* Thumbnails: rendered here, one at a time, for the tiles on screen        */
/* ------------------------------------------------------------------------ */

const THUMB = 240;
const thumbCache = new Map();
let thumbRenderer = null;
let thumbScene = null;
let thumbCamera = null;
let thumbSun = null;
const thumbQueue = [];
let thumbBusy = false;

function thumbSetup() {
  thumbRenderer = new THREE.WebGLRenderer({ antialias: true, alpha: true, preserveDrawingBuffer: true });
  thumbRenderer.setPixelRatio(1);
  thumbRenderer.setSize(THUMB, THUMB, false);
  thumbRenderer.toneMapping = THREE.NeutralToneMapping;
  thumbRenderer.shadowMap.enabled = true;
  thumbRenderer.shadowMap.type = THREE.PCFSoftShadowMap;
  thumbScene = new THREE.Scene();
  const pmrem = new THREE.PMREMGenerator(thumbRenderer);
  thumbScene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
  thumbScene.environmentIntensity = 0.5;
  thumbSun = makeLights(thumbScene);
  thumbCamera = new THREE.PerspectiveCamera(30, 1, 0.1, 1000);
}

function previewVersion(item) {
  return item.versions[0];
}

function requestThumb(item, img, spinner) {
  if (previewVersion(item).kind === "image") {
    img.src = previewVersion(item).file;
    img.hidden = false;
    spinner.remove();
    return;
  }
  const cached = thumbCache.get(item.id);
  if (cached) {
    img.src = cached;
    img.hidden = false;
    spinner.remove();
    return;
  }
  thumbQueue.push({ item, img, spinner });
  pumpThumbs();
}

async function pumpThumbs() {
  if (thumbBusy) return;
  thumbBusy = true;
  try {
    while (thumbQueue.length) {
      const job = thumbQueue.shift();
      if (!job.img.isConnected) continue;
      let url = thumbCache.get(job.item.id);
      if (!url) {
        try {
          url = await renderThumb(job.item);
        } catch (err) {
          console.warn(err);
          url = null;
        }
        if (url) thumbCache.set(job.item.id, url);
      }
      if (url) {
        job.img.src = url;
        job.img.hidden = false;
      }
      job.spinner.remove();
      await new Promise((r) => requestAnimationFrame(r));
    }
  } finally {
    thumbBusy = false;
  }
}

async function renderThumb(item) {
  if (!thumbRenderer) thumbSetup();
  const version = previewVersion(item);
  const { object, clips } = await loadVersion(version);
  // A pose from the idle clip looks more alive than the bind pose.
  if (clips.length) {
    const mixer = new THREE.AnimationMixer(object);
    const clip = clips.find((c) => /idle/i.test(c.name)) ?? clips[0];
    mixer.clipAction(clip).play();
    mixer.update(0.01);
  }
  thumbScene.add(object);
  const box = visibleBox(object);
  const ground = makeGround(box);
  ground.group.children[1].visible = false; // no grid lines in thumbnails
  thumbScene.add(ground.group);
  placeSun(thumbSun, box);
  frame(thumbCamera, null, box, frontOf(version));
  thumbCamera.lookAt(box.getCenter(new THREE.Vector3()));
  thumbRenderer.render(thumbScene, thumbCamera);
  const url = thumbRenderer.domElement.toDataURL("image/png");
  thumbScene.remove(object);
  thumbScene.remove(ground.group);
  disposeObject(object);
  return url;
}

function disposeObject(object) {
  object.traverse((o) => {
    if (o.isMesh && !Object.values(geometries).includes(o.geometry)) {
      o.geometry.dispose();
      const mats = Array.isArray(o.material) ? o.material : [o.material];
      for (const m of mats) {
        if ([...materials.values()].includes(m)) continue;
        for (const v of Object.values(m)) if (v && v.isTexture) v.dispose();
        m.dispose();
      }
    }
  });
}

const thumbObserver = new IntersectionObserver(
  (entries) => {
    for (const e of entries) {
      if (!e.isIntersecting) continue;
      thumbObserver.unobserve(e.target);
      const { item } = e.target.__thumb;
      requestThumb(item, e.target.querySelector("img"), e.target.querySelector(".loading"));
    }
  },
  { rootMargin: "200px" },
);

/* ------------------------------------------------------------------------ */
/* The 3D stage for one design                                              */
/* ------------------------------------------------------------------------ */

const stage = {
  renderer: null,
  scene: null,
  camera: null,
  controls: null,
  sun: null,
  object: null,
  ground: null,
  mixer: null,
  clock: new THREE.Clock(),
  running: false,
  autoRotate: storage("designs.autoRotate") !== "0",
  showGrid: storage("designs.grid") !== "0",
  box: null,
  front: -1,
  token: 0,
};

function stageSetup() {
  const r = new THREE.WebGLRenderer({ antialias: true, alpha: true });
  r.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  r.toneMapping = THREE.NeutralToneMapping;
  r.shadowMap.enabled = true;
  r.shadowMap.type = THREE.PCFSoftShadowMap;
  r.domElement.tabIndex = 0;
  stage.renderer = r;
  stage.scene = new THREE.Scene();
  const pmrem = new THREE.PMREMGenerator(r);
  stage.scene.environment = pmrem.fromScene(new RoomEnvironment(), 0.04).texture;
  stage.scene.environmentIntensity = 0.5;
  stage.sun = makeLights(stage.scene);
  stage.camera = new THREE.PerspectiveCamera(35, 1, 0.1, 1000);
  stage.controls = new OrbitControls(stage.camera, r.domElement);
  stage.controls.enableDamping = true;
  stage.controls.autoRotateSpeed = 1.2;
  stage.controls.addEventListener("start", () => {
    // Grabbing the model stops the spin, as a person expects.
    if (stage.controls.autoRotate) setAutoRotate(false);
  });
  new ResizeObserver(() => resizeStage()).observe(r.domElement);
}

function resizeStage() {
  const canvas = stage.renderer?.domElement;
  if (!canvas || !canvas.isConnected) return;
  const w = canvas.clientWidth;
  const h = canvas.clientHeight;
  if (w === 0 || h === 0) return;
  stage.renderer.setSize(w, h, false);
  stage.camera.aspect = w / h;
  stage.camera.updateProjectionMatrix();
}

function startLoop() {
  if (stage.running) return;
  stage.running = true;
  stage.clock.getDelta();
  const tick = () => {
    if (!stage.running) return;
    if (!stage.renderer.domElement.isConnected) {
      stage.running = false;
      return;
    }
    const dt = Math.min(stage.clock.getDelta(), 0.1);
    stage.mixer?.update(dt);
    stage.controls.update();
    stage.renderer.render(stage.scene, stage.camera);
    requestAnimationFrame(tick);
  };
  requestAnimationFrame(tick);
}

function setAutoRotate(on) {
  stage.autoRotate = on;
  stage.controls.autoRotate = on;
  storage("designs.autoRotate", on ? "1" : "0");
  document.querySelectorAll("[data-tool=spin]").forEach((b) => b.classList.toggle("on", on));
}

function setGrid(on) {
  stage.showGrid = on;
  storage("designs.grid", on ? "1" : "0");
  if (stage.ground) stage.ground.group.children[1].visible = on;
  document.querySelectorAll("[data-tool=grid]").forEach((b) => b.classList.toggle("on", on));
}

async function showVersion(item, index, ui) {
  const token = ++stage.token;
  const version = item.versions[index];
  ui.clips.replaceChildren();
  ui.clipsSection.hidden = true;
  const picture = version.kind === "image";
  stage.renderer.domElement.hidden = picture;
  ui.picture.hidden = !picture;
  ui.tools.hidden = picture;
  ui.hint.hidden = picture;
  if (picture) {
    ui.overlay.replaceChildren();
    ui.picture.onload = () => {
      if (token !== stage.token) return;
      ui.facts.replaceChildren(
        ...pictureFacts(item, version, ui.picture).flatMap(([k, v]) => [el("dt", { text: k }), el("dd", { text: v })]),
      );
    };
    ui.picture.src = version.file;
    return;
  }
  ui.overlay.replaceChildren(el("div", { class: "loading" }));
  let loaded;
  try {
    loaded = await loadVersion(version);
  } catch (err) {
    if (token === stage.token) ui.overlay.replaceChildren(el("div", { text: err.message }));
    return;
  }
  if (token !== stage.token) {
    disposeObject(loaded.object);
    return;
  }
  ui.overlay.replaceChildren();
  if (stage.object) {
    stage.scene.remove(stage.object);
    disposeObject(stage.object);
  }
  if (stage.ground) stage.scene.remove(stage.ground.group);
  stage.mixer?.stopAllAction();
  stage.mixer = null;

  stage.object = loaded.object;
  stage.scene.add(stage.object);
  stage.box = visibleBox(stage.object);
  stage.front = frontOf(version);
  stage.ground = makeGround(stage.box);
  stage.ground.group.children[1].visible = stage.showGrid;
  stage.scene.add(stage.ground.group);
  placeSun(stage.sun, stage.box);
  resizeStage();
  frame(stage.camera, stage.controls, stage.box, stage.front);
  stage.controls.autoRotate = stage.autoRotate;

  // Animation clips (idle, walk, ...): one button each.
  if (loaded.clips.length) {
    stage.mixer = new THREE.AnimationMixer(stage.object);
    const buttons = [];
    const play = (clip) => {
      stage.mixer.stopAllAction();
      if (clip) stage.mixer.clipAction(clip).reset().play();
      buttons.forEach((b) => b.classList.toggle("on", b.__clip === clip));
    };
    for (const clip of loaded.clips) {
      const b = el("button", { class: "chip", onclick: () => play(clip) }, clip.name || "Clip");
      b.__clip = clip;
      buttons.push(b);
    }
    const still = el("button", { class: "chip", onclick: () => play(null) }, "Still");
    still.__clip = null;
    buttons.push(still);
    ui.clips.replaceChildren(...buttons);
    ui.clipsSection.hidden = false;
    play(loaded.clips.find((c) => /idle/i.test(c.name)) ?? loaded.clips[0]);
  } else {
    ui.clipsSection.hidden = true;
  }

  // Facts for this version.
  const size = stage.box.getSize(new THREE.Vector3());
  const facts = [];
  if (item.game) facts.push(["Game", item.game]);
  if (item.tier) facts.push(["Tier", item.tier]);
  facts.push(["Size", `${fmt(size.x)} × ${fmt(size.y)} × ${fmt(size.z)} studs (wide × tall × deep)`]);
  if (version.kind === "parts") {
    facts.push(["Pieces", version.pieces.toLocaleString()]);
  } else {
    let tris = 0;
    stage.object.traverse((o) => {
      if (o.isMesh && o.visible && !LOD.test(o.name)) {
        const g = o.geometry;
        tris += (g.index ? g.index.count : g.attributes.position.count) / 3;
      }
    });
    facts.push(["Triangles", Math.round(tris).toLocaleString()]);
    facts.push(["File size", `${(version.bytes / 1024).toFixed(0)} KB`]);
  }
  if (item.copies > 1) facts.push(["In the game", `${item.copies} copies`]);
  if (item.where && version.kind === "parts" && !item.tier) facts.push(["Built at", item.where]);
  if (version.updated) facts.push(["Updated", new Date(version.updated).toLocaleString()]);
  if (version.source) facts.push(["File", `designs/${version.source}`]);
  facts.push(["Grid square", `${stage.ground.step} stud${stage.ground.step === 1 ? "" : "s"}`]);
  ui.facts.replaceChildren(...facts.flatMap(([k, v]) => [el("dt", { text: k }), el("dd", { text: v })]));
}

function pictureFacts(item, version, img) {
  const facts = [];
  if (item.game) facts.push(["Game", item.game]);
  facts.push(["Picture", `${img.naturalWidth} × ${img.naturalHeight} pixels`]);
  if (version.updated) facts.push(["Updated", new Date(version.updated).toLocaleString()]);
  if (version.source) facts.push(["File", `designs/${version.source}`]);
  return facts;
}

function fmt(n) {
  return n >= 10 ? n.toFixed(0) : n.toFixed(2).replace(/\.?0+$/, "");
}

/* ------------------------------------------------------------------------ */
/* Navigation: folder, design or search, kept in the address (#...)         */
/* ------------------------------------------------------------------------ */

let current = { kind: "folder", path: [] };
const history = [];
let historyIndex = -1;

function encodePath(path) {
  return path.map(encodeURIComponent).join("/");
}

function routeToHash(route) {
  if (route.kind === "search") return `#search=${encodeURIComponent(route.query)}`;
  if (route.kind === "item") return `#design=${encodePath(route.path)}${route.version ? `&v=${route.version}` : ""}`;
  return `#folder=${encodePath(route.path)}`;
}

function hashToRoute(hash) {
  const h = hash.replace(/^#/, "");
  const [main, extra] = h.split("&");
  const [kind, value = ""] = main.split("=");
  const path = value ? value.split("/").map(decodeURIComponent) : [];
  if (kind === "search") return { kind: "search", query: decodeURIComponent(value) };
  if (kind === "design") {
    const version = extra?.startsWith("v=") ? Number(extra.slice(2)) || 0 : 0;
    return { kind: "item", path, version };
  }
  return { kind: "folder", path };
}

function go(route, { push = true, replace = false } = {}) {
  current = route;
  if (push) {
    history.splice(historyIndex + 1);
    history.push(route);
    historyIndex = history.length - 1;
  } else if (replace && historyIndex >= 0) {
    history[historyIndex] = route;
  }
  const hash = routeToHash(route);
  if (location.hash !== hash) {
    try {
      window.history.replaceState(null, "", hash);
    } catch {
      /* some browsers refuse on file:// pages; the viewer works without it */
    }
  }
  if (route.kind !== "search") storage("designs.last", hash);
  render();
}

function render() {
  stage.token++;
  renderCrumbs();
  renderTree();
  updateNavButtons();
  const main = $("#main");
  main.scrollTop = 0;
  if (current.kind === "search") return renderSearch(main, current.query);
  if (current.kind === "item") {
    const item = itemAt(current.path);
    if (item) return renderItem(main, item, current.version ?? 0);
    current = { kind: "folder", path: current.path.slice(0, -1) };
  }
  const folder = folderAt(current.path);
  if (!folder) {
    current = { kind: "folder", path: [] };
    return renderFolder(main, root);
  }
  return renderFolder(main, folder);
}

function updateNavButtons() {
  $("#back").disabled = historyIndex <= 0;
  $("#forward").disabled = historyIndex >= history.length - 1;
  $("#up").disabled = current.kind === "folder" && current.path.length === 0 && current.kind !== "search";
}

function renderCrumbs() {
  const crumbs = $("#crumbs");
  const parts = [];
  if (current.kind === "search") {
    parts.push(el("button", { class: "crumb", onclick: () => go({ kind: "folder", path: [] }) }, "Designs"));
    parts.push(el("span", { class: "crumb-sep" }, "›"));
    parts.push(el("span", { class: "crumb current" }, `Search: “${current.query}”`));
  } else {
    const path = current.path;
    const all = [["Designs", []], ...path.map((p, i) => [p, path.slice(0, i + 1)])];
    all.forEach(([name, p], i) => {
      if (i > 0) parts.push(el("span", { class: "crumb-sep" }, "›"));
      const last = i === all.length - 1;
      const isItem = last && current.kind === "item";
      parts.push(
        el(
          "button",
          {
            class: `crumb${last ? " current" : ""}`,
            onclick: () => go(isItem ? current : { kind: "folder", path: p }),
          },
          name,
        ),
      );
    });
  }
  crumbs.replaceChildren(...parts);
  crumbs.scrollLeft = crumbs.scrollWidth;
}

const expanded = new Set(JSON.parse(storage("designs.expanded") || "[]"));

function renderTree() {
  const tree = $("#tree");
  const openPath = current.kind === "search" ? [] : current.kind === "item" ? current.path.slice(0, -1) : current.path;
  for (let i = 1; i <= openPath.length; i++) expanded.add(keyOf(openPath.slice(0, i)));
  const rows = [];
  const currentKey = keyOf(openPath);
  const addRows = (folder, depth) => {
    for (const f of sortedFolders(folder)) {
      const key = keyOf(f.path);
      const hasChildren = f.folders.size > 0;
      const isOpen = expanded.has(key);
      const row = el(
        "button",
        {
          class: `tree-row${key === currentKey && current.kind !== "search" ? " current" : ""}`,
          style: `padding-left:${6 + depth * 14}px`,
          title: f.path.join(" › "),
          onclick: (e) => {
            if (e.target.classList.contains("chev") && hasChildren) {
              if (isOpen) expanded.delete(key);
              else expanded.add(key);
              storage("designs.expanded", JSON.stringify([...expanded]));
              renderTree();
              return;
            }
            expanded.add(key);
            go({ kind: "folder", path: f.path });
          },
        },
        el("span", { class: "chev" }, hasChildren ? (isOpen ? "▼" : "▶") : ""),
        el("span", { class: "name" }, f.name),
        el("span", { class: "count" }, f.total),
      );
      rows.push(row);
      if (hasChildren && isOpen) addRows(f, depth + 1);
    }
  };
  rows.push(
    el(
      "button",
      {
        class: `tree-row${currentKey === "" && current.kind === "folder" ? " current" : ""}`,
        onclick: () => go({ kind: "folder", path: [] }),
      },
      el("span", { class: "chev" }, ""),
      el("span", { class: "name" }, "All designs"),
      el("span", { class: "count" }, root.total),
    ),
  );
  addRows(root, 0);
  tree.replaceChildren(...rows);
}

// The first designs inside a folder (and its sub-folders), for its preview.
function firstItems(folder, n) {
  const out = sortedItems(folder.items).slice(0, n);
  for (const f of sortedFolders(folder)) {
    if (out.length >= n) break;
    out.push(...firstItems(f, n - out.length));
  }
  return out;
}

function folderTile(folder) {
  const peek = firstItems(folder, 4);
  const cells = peek.map((item) => {
    const cell = el("div", { class: "peek-cell" }, el("img", { alt: "", hidden: true, draggable: "false" }), el("div", { class: "loading" }));
    cell.__thumb = { item };
    thumbObserver.observe(cell);
    return cell;
  });
  return el(
    "button",
    {
      class: "tile folder",
      title: folder.path.join(" › "),
      onclick: () => go({ kind: "folder", path: folder.path }),
    },
    el(
      "div",
      { class: "thumb" },
      el("div", { class: `peek peek-${Math.max(cells.length, 1)}` }, cells),
      el("span", { class: "folder-badge", "aria-hidden": "true" }, "📁"),
    ),
    el(
      "div",
      { class: "meta" },
      el("div", { class: "title" }, folder.name),
      el("div", { class: "info" }, `Folder · ${folder.total} design${folder.total === 1 ? "" : "s"}`),
    ),
  );
}

function itemTile(item, showPath) {
  const img = el("img", { alt: "", hidden: true, draggable: "false" });
  const spinner = el("div", { class: "loading" });
  const isNew = item.updated && Date.now() - item.updated < NEW_FOR_MS;
  const thumb = el(
    "div",
    { class: "thumb" },
    img,
    spinner,
    item.tier ? el("span", { class: "badge", style: `background:${TIER_COLORS[item.tier] ?? "#667085"}` }, item.tier) : null,
    isNew ? el("span", { class: "new-badge" }, "New") : null,
  );
  thumb.__thumb = { item };
  thumbObserver.observe(thumb);
  const info = showPath
    ? item.path.join(" › ")
    : [item.game, item.copies > 1 ? `×${item.copies} in game` : null, item.versions.length > 1 ? `${item.versions.length} versions` : null]
        .filter(Boolean)
        .join(" · ");
  return el(
    "button",
    {
      class: "tile",
      title: [...item.path, item.name].join(" › "),
      onclick: () => go({ kind: "item", path: [...item.path, item.name] }),
    },
    thumb,
    el("div", { class: "meta" }, el("div", { class: "title" }, item.name), el("div", { class: "info" }, info || " ")),
  );
}

function renderFolder(main, folder) {
  const folders = sortedFolders(folder);
  const list = sortedItems(folder.items);
  const title = folder === root ? "All designs" : folder.name;
  const parts = [
    el("h2", {}, title),
    el(
      "p",
      { class: "sub" },
      folder === root
        ? `${root.total} designs from every game. Open a folder, or search at the top right.`
        : `${folder.total} design${folder.total === 1 ? "" : "s"}`,
    ),
  ];
  if (folders.length) {
    if (list.length) parts.push(el("div", { class: "section-label" }, "Folders"));
    parts.push(el("div", { class: "grid" }, folders.map(folderTile)));
  }
  if (list.length) {
    if (folders.length) parts.push(el("div", { class: "section-label" }, "Designs"));
    parts.push(el("div", { class: "grid" }, list.map((it) => itemTile(it, false))));
  }
  if (!folders.length && !list.length) parts.push(el("div", { class: "empty" }, "This folder is empty."));
  main.replaceChildren(el("div", { class: "listing" }, parts));
}

function search(query) {
  const words = query.toLowerCase().split(/\s+/).filter(Boolean);
  if (!words.length) return { folders: [], items: [] };
  const hit = (text) => words.every((w) => text.includes(w));
  const folders = [];
  const walk = (f) => {
    for (const child of f.folders.values()) {
      if (hit(child.path.join(" ").toLowerCase()) && words.some((w) => child.name.toLowerCase().includes(w))) folders.push(child);
      walk(child);
    }
  };
  walk(root);
  const found = items.filter((it) => hit(it.haystack));
  // Name matches first.
  const score = (it) => (words.every((w) => it.name.toLowerCase().includes(w)) ? 0 : 1);
  found.sort((a, b) => score(a) - score(b) || a.name.localeCompare(b.name, undefined, { numeric: true }));
  return { folders, items: found };
}

function renderSearch(main, query) {
  const { folders, items: found } = search(query);
  const parts = [
    el("h2", {}, `Search: “${query}”`),
    el("p", { class: "sub" }, `${found.length} design${found.length === 1 ? "" : "s"}${folders.length ? `, ${folders.length} folder${folders.length === 1 ? "" : "s"}` : ""}`),
  ];
  if (folders.length) {
    parts.push(el("div", { class: "section-label" }, "Folders"));
    parts.push(el("div", { class: "grid" }, folders.slice(0, 24).map(folderTile)));
  }
  if (found.length) {
    if (folders.length) parts.push(el("div", { class: "section-label" }, "Designs"));
    parts.push(el("div", { class: "grid" }, found.map((it) => itemTile(it, true))));
  }
  if (!found.length && !folders.length) {
    parts.push(el("div", { class: "empty" }, "Nothing matches. Try fewer or shorter words, like “egg” or “barn”."));
  }
  main.replaceChildren(el("div", { class: "listing" }, parts));
}

function renderItem(main, item, versionIndex) {
  if (!stage.renderer) stageSetup();
  const siblings = sortedItems(item.folder.items);
  const at = siblings.indexOf(item);
  const prev = siblings[at - 1];
  const next = siblings[at + 1];
  const open = (it) => go({ kind: "item", path: [...it.path, it.name] }, { push: false, replace: true });

  const ui = {
    overlay: el("div", { class: "overlay" }),
    clips: el("div", { class: "chips" }),
    clipsSection: null,
    facts: el("dl", { class: "facts" }),
    picture: el("img", { class: "picture", alt: item.name, hidden: true }),
    tools: null,
    hint: el("div", { class: "hint" }, "Drag to turn · Scroll to zoom · Right-drag to move"),
  };
  ui.clipsSection = el("section", { hidden: true }, el("h3", {}, "Animations"), ui.clips);

  const versionChips = item.versions.map((v, i) =>
    el(
      "button",
      {
        class: `chip${i === versionIndex ? " on" : ""}`,
        onclick: () => go({ kind: "item", path: [...item.path, item.name], version: i }, { push: false, replace: true }),
      },
      v.label,
    ),
  );

  const images = item.images.length
    ? el(
        "section",
        {},
        el("h3", {}, "Pictures"),
        el(
          "div",
          { class: "images" },
          item.images.map((im) =>
            el(
              "button",
              { title: im.name, onclick: () => openLightbox(im.file) },
              el("img", { src: im.file, alt: im.name, loading: "lazy" }),
            ),
          ),
        ),
      )
    : null;

  const details = Object.entries(item.details ?? {});
  const canvas = stage.renderer.domElement;
  const tools = (ui.tools = el(
    "div",
    { class: "stage-tools" },
    el("button", { class: `chip${stage.autoRotate ? " on" : ""}`, "data-tool": "spin", onclick: () => setAutoRotate(!stage.autoRotate) }, "Spin"),
    el("button", { class: `chip${stage.showGrid ? " on" : ""}`, "data-tool": "grid", onclick: () => setGrid(!stage.showGrid) }, "Grid"),
    el("button", { class: "chip", onclick: () => frame(stage.camera, stage.controls, stage.box, stage.front) }, "Reset view"),
  ));
  const nav = el(
    "div",
    { class: "stage-nav" },
    el("button", { class: "chip", disabled: !prev, title: "Previous (Left arrow)", onclick: () => prev && open(prev) }, prev ? `← ${prev.name}` : "←"),
    el("button", { class: "chip", disabled: !next, title: "Next (Right arrow)", onclick: () => next && open(next) }, next ? `${next.name} →` : "→"),
  );

  main.replaceChildren(
    el(
      "div",
      { class: "detail" },
      el(
        "div",
        { class: "stage" },
        canvas,
        ui.picture,
        ui.overlay,
        nav,
        tools,
        ui.hint,
      ),
      el(
        "aside",
        { class: "panel" },
        el("h2", {}, item.name),
        el("div", { class: "where" }, item.path.join(" › ")),
        item.versions.length > 1 ? el("section", {}, el("h3", {}, "Versions"), el("div", { class: "chips" }, versionChips)) : null,
        ui.clipsSection,
        el("section", {}, el("h3", {}, "Details"), ui.facts),
        details.length
          ? el(
              "section",
              {},
              el("h3", {}, "From the design file"),
              el("dl", { class: "facts" }, details.flatMap(([k, v]) => [el("dt", { text: spaced(k) }), el("dd", { text: v })])),
            )
          : null,
        images,
      ),
    ),
  );
  resizeStage();
  startLoop();
  showVersion(item, Math.min(versionIndex, item.versions.length - 1), ui);
}

function spaced(key) {
  const s = key.replace(/([a-z])([A-Z])/g, "$1 $2").replace(/_/g, " ");
  return s.charAt(0).toUpperCase() + s.slice(1).toLowerCase();
}

function openLightbox(src) {
  const box = $("#lightbox");
  box.querySelector("img").src = src;
  box.hidden = false;
}

/* ------------------------------------------------------------------------ */
/* Start                                                                    */
/* ------------------------------------------------------------------------ */

function start() {
  if (!catalog) {
    $("#main").replaceChildren(
      el(
        "div",
        { class: "notice" },
        el("h2", {}, "No designs yet"),
        el("p", {}, "This viewer has no catalog next to it. Build it with tools/designs/build.sh."),
      ),
    );
    return;
  }

  const theme = storage("designs.theme");
  if (theme) document.documentElement.dataset.theme = theme;

  $("#back").onclick = () => {
    if (historyIndex > 0) go(history[--historyIndex], { push: false });
  };
  $("#forward").onclick = () => {
    if (historyIndex < history.length - 1) go(history[++historyIndex], { push: false });
  };
  $("#up").onclick = () => goUp();

  const input = $("#search");
  let timer = null;
  let searchStart = null;
  input.addEventListener("input", () => {
    clearTimeout(timer);
    timer = setTimeout(() => {
      const q = input.value.trim();
      if (q) {
        if (current.kind !== "search") {
          searchStart = current;
          go({ kind: "search", query: q });
        } else {
          go({ kind: "search", query: q }, { push: false, replace: true });
        }
      } else if (current.kind === "search") {
        go(searchStart ?? { kind: "folder", path: [] }, { push: false, replace: true });
      }
    }, 120);
  });
  input.addEventListener("keydown", (e) => {
    if (e.key === "Enter") {
      const first = document.querySelector("#main .tile");
      if (first) first.click();
    } else if (e.key === "Escape") {
      input.value = "";
      input.dispatchEvent(new Event("input"));
      input.blur();
    }
  });

  $("#lightbox").onclick = () => ($("#lightbox").hidden = true);

  document.addEventListener("keydown", (e) => {
    const typing = e.target instanceof HTMLInputElement;
    if ((e.key === "/" && !typing) || (e.key.toLowerCase() === "f" && (e.ctrlKey || e.metaKey))) {
      e.preventDefault();
      input.focus();
      input.select();
      return;
    }
    if (typing) return;
    if (!$("#lightbox").hidden && e.key === "Escape") {
      $("#lightbox").hidden = true;
      return;
    }
    if (e.altKey && e.key === "ArrowLeft") return $("#back").click();
    if (e.altKey && e.key === "ArrowRight") return $("#forward").click();
    if (e.key === "Backspace" || e.key === "Escape") {
      e.preventDefault();
      return goUp();
    }
    if (current.kind === "item" && (e.key === "ArrowLeft" || e.key === "ArrowRight")) {
      const chip = document.querySelectorAll(".stage-nav .chip")[e.key === "ArrowLeft" ? 0 : 1];
      if (chip && !chip.disabled) chip.click();
    }
  });

  window.addEventListener("hashchange", () => go(hashToRoute(location.hash)));

  // Status bar: counts, when built, theme switch.
  const built = new Date(catalog.builtAt);
  const themeBtn = el(
    "button",
    {
      onclick: () => {
        const dark =
          document.documentElement.dataset.theme === "dark" ||
          (!document.documentElement.dataset.theme && matchMedia("(prefers-color-scheme: dark)").matches);
        const next = dark ? "light" : "dark";
        document.documentElement.dataset.theme = next;
        storage("designs.theme", next);
      },
    },
    "Light / dark",
  );
  $("#status").replaceChildren(
    el("span", {}, `${items.length} designs · updated ${built.toLocaleString()}`),
    themeBtn,
  );

  const start = location.hash ? location.hash : storage("designs.last");
  go(start ? hashToRoute(start) : { kind: "folder", path: [] });
}

function goUp() {
  if (current.kind === "search") {
    $("#search").value = "";
    return go({ kind: "folder", path: [] });
  }
  if (current.kind === "item") return go({ kind: "folder", path: current.path.slice(0, -1) });
  if (current.path.length) go({ kind: "folder", path: current.path.slice(0, -1) });
}

start();
