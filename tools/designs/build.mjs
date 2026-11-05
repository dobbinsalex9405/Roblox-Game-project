#!/usr/bin/env node
// Builds the design viewer: one folder that opens in any browser straight
// from disk (no server, no install), with every design in it.
//
//   node tools/designs/build.mjs [--models build/designs/game-models.json]
//                                [--drops /mnt/project-files/designs]
//                                [--out build/design-viewer]
//
// Two sources of designs:
//   1. The models the games build (tools/designs/export.luau writes them):
//      sorted into folders by tools/designs/catalog.json.
//   2. Dropped designs: any folder under --drops that holds a .glb (or, as
//      its last folder, only pictures: a concept render). Its path
//      below --drops is its place in the viewer, e.g.
//      Creatures/Hatchery Heist/Common/Bunny/Bunny.glb. Several .glb files in
//      one folder are versions; .png/.gif/.jpg files are shown beside the
//      model; meta.json is shown as details.
// A dropped design whose folder matches a game model (same path, any case)
// becomes another version of it, so a Blender mesh sits next to what the
// game draws today.
//
// Browsers will not let a page opened from disk fetch() files beside it, but
// they do run <script> files. So each .glb is written as a small script that
// hands its bytes to the viewer (data/models/<hash>.js), and the catalog is a
// script too. File names are content hashes: copying the folder again only
// copies what changed.

import { createHash } from "node:crypto";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.resolve(HERE, "..", "..");

function parseArgs(argv) {
  const out = {
    models: path.join(REPO, "build/designs/game-models.json"),
    drops: process.env.DESIGNS_DIR || "/mnt/project-files/designs",
    out: path.join(REPO, "build/design-viewer"),
  };
  for (let i = 0; i < argv.length; i++) {
    const key = argv[i].replace(/^--/, "");
    if (!(key in out)) throw new Error(`unknown option ${argv[i]}`);
    out[key] = path.resolve(argv[++i]);
  }
  return out;
}

const IMAGE_EXT = new Set([".png", ".gif", ".jpg", ".jpeg", ".webp"]);
const MAX_IMAGES = 6;

function hashOf(buffer) {
  return createHash("sha256").update(buffer).digest("hex").slice(0, 16);
}

// Folder and design names match ignoring case and spaces, so a drop named
// after a config id ("EmberFox") meets the game's "Ember Fox".
function keyOf(parts) {
  return parts.map((p) => p.replace(/\s+/g, "").toLowerCase()).join("/");
}

function fill(template, values) {
  return template.replace(/\{(\w+)\}/g, (_, k) => values[k] ?? "");
}

// "BasicEgg" -> "Basic Egg", "GoldenNest" -> "Golden Nest".
function spaced(name) {
  return name.replace(/([a-z])([A-Z])/g, "$1 $2");
}

function matches(match, d) {
  for (const [k, v] of Object.entries(match)) {
    if (k === "creature" || k === "map") {
      if (Boolean(d[k]) !== v) return false;
    } else if ((d[k] ?? "") !== v) {
      return false;
    }
  }
  return true;
}

// Game models -> items.
function gameItems(models, catalog) {
  const items = [];
  const named = new Map();
  for (const d of models) {
    const gameName = catalog.games[d.game] ?? d.game;
    const rule = catalog.rules.find((r) => matches(r.match, d));
    const values = { game: gameName, name: spaced(d.name), rarity: d.rarity ?? "" };
    const folder = fill(rule.folder, values).split("/").filter(Boolean);
    if (rule.folder.startsWith("Other/") && d.where) folder.push(...d.where.split(" > "));
    const name = rule.name ? fill(rule.name, values) : spaced(d.name);
    const item = {
      path: folder,
      name,
      game: gameName,
      tier: d.rarity ?? null,
      copies: d.copies,
      versions: [
        {
          label: "In game now",
          kind: "parts",
          size: d.size,
          pieces: d.parts.length,
          parts: d.parts,
        },
      ],
      images: [],
      details: {},
      where: d.where ? `${gameName} > ${d.where} > ${d.name}` : `${gameName} > ${d.name}`,
    };
    const key = keyOf([...folder, name]);
    const list = named.get(key) ?? [];
    list.push(item);
    named.set(key, list);
    items.push(item);
  }
  // Two different models with one name in one folder: number them.
  for (const list of named.values()) {
    if (list.length > 1) list.forEach((item, i) => (item.name = `${item.name} ${i + 1}`));
  }
  return items;
}

function walkDrops(root) {
  const found = [];
  if (!fs.existsSync(root)) return found;
  const visit = (dir, rel) => {
    let entries;
    try {
      entries = fs.readdirSync(dir, { withFileTypes: true });
    } catch {
      return;
    }
    const files = entries.filter((e) => e.isFile()).map((e) => e.name);
    const hasGlb = files.some((f) => f.toLowerCase().endsWith(".glb"));
    // A last folder with only pictures (a concept render) is a picture design.
    const hasSub = entries.some((e) => e.isDirectory() && !e.name.startsWith("."));
    const pictures = !hasGlb && !hasSub && files.some((f) => IMAGE_EXT.has(path.extname(f).toLowerCase()));
    if (hasGlb || pictures) found.push({ dir, rel, files, pictures });
    for (const e of entries) {
      if (e.isDirectory() && !e.name.startsWith(".")) visit(path.join(dir, e.name), [...rel, e.name]);
    }
  };
  visit(root, []);
  return found;
}

function readJson(file) {
  try {
    return JSON.parse(fs.readFileSync(file, "utf8"));
  } catch {
    return null;
  }
}

// meta.json -> a few readable lines (nested objects are left out).
function detailsOf(meta) {
  const out = {};
  if (!meta || typeof meta !== "object") return out;
  for (const [k, v] of Object.entries(meta)) {
    // Shown elsewhere already (tier, triangles) or not readable.
    if (["parts", "files", "id", "rarity", "tris"].includes(k)) continue;
    if (v === null || v === "" || (Array.isArray(v) && v.length === 0)) continue;
    if (typeof v === "object") {
      if (Array.isArray(v) && v.every((x) => typeof x !== "object")) out[k] = v.join(", ");
      else if (k === "clips" && typeof v === "object") out[k] = Object.keys(v).join(", ");
      continue;
    }
    out[k] = String(v);
  }
  return out;
}

function writeOnce(file, data) {
  if (fs.existsSync(file)) return;
  fs.mkdirSync(path.dirname(file), { recursive: true });
  fs.writeFileSync(file, data);
}

function build(opts) {
  const catalog = readJson(path.join(HERE, "catalog.json"));
  const models = readJson(opts.models);
  if (!models) {
    throw new Error(`${opts.models} is missing: run \`lune run tools/designs/export all\` first`);
  }
  const items = gameItems(models.designs, catalog);
  const byKey = new Map(items.map((it) => [keyOf([...it.path, it.name]), it]));

  // Fresh output each build, so designs that were removed disappear.
  fs.rmSync(opts.out, { recursive: true, force: true });
  const dataDir = path.join(opts.out, "data");
  fs.mkdirSync(path.join(dataDir, "models"), { recursive: true });
  fs.mkdirSync(path.join(dataDir, "images"), { recursive: true });

  let dropped = 0;
  for (const drop of walkDrops(opts.drops)) {
    if (drop.rel.length < 2) continue; // needs at least <What it is>/<Name>
    const folder = drop.rel.slice(0, -1);
    const name = drop.rel[drop.rel.length - 1];
    const key = keyOf(drop.rel);
    let item = byKey.get(key);
    if (!item) {
      item = {
        path: folder,
        name: spaced(name), // "PygmyGoat" -> "Pygmy Goat"
        game: folder[1] ?? "",
        tier: catalog.tiers.find((t) => folder.includes(t)) ?? null,
        copies: 0,
        versions: [],
        images: [],
        details: {},
        where: null,
      };
      byKey.set(key, item);
      items.push(item);
    }
    const glbs = drop.files
      .filter((f) => f.toLowerCase().endsWith(".glb"))
      .map((f) => ({ f, mtime: fs.statSync(path.join(drop.dir, f)).mtimeMs }))
      .sort((a, b) => b.mtime - a.mtime);
    const meta = readJson(path.join(drop.dir, "meta.json"));
    const added = [];
    for (const { f, mtime } of glbs) {
      const bytes = fs.readFileSync(path.join(drop.dir, f));
      const hash = hashOf(bytes);
      writeOnce(
        path.join(dataDir, "models", `${hash}.js`),
        `window.__designData(${JSON.stringify(hash)},${JSON.stringify(bytes.toString("base64"))});\n`,
      );
      const stem = f.replace(/\.glb$/i, "");
      added.push({
        label: glbs.length === 1 || keyOf([stem]) === keyOf([name]) ? "Design" : stem,
        kind: "glb",
        file: `data/models/${hash}.js`,
        hash,
        bytes: bytes.length,
        updated: new Date(mtime).toISOString(),
        source: path.join(...drop.rel, f),
      });
    }
    // Designs first: they are what someone made to be looked at.
    item.versions = [...added, ...item.versions];
    item.details = { ...item.details, ...detailsOf(meta) };
    const images = drop.files
      .filter((f) => IMAGE_EXT.has(path.extname(f).toLowerCase()))
      .sort((a, b) => (a.startsWith("hero") ? -1 : b.startsWith("hero") ? 1 : a.localeCompare(b)))
      .slice(0, MAX_IMAGES);
    for (const f of images) {
      const full = path.join(drop.dir, f);
      const bytes = fs.readFileSync(full);
      const file = `data/images/${hashOf(bytes)}${path.extname(f).toLowerCase()}`;
      writeOnce(path.join(opts.out, file), bytes);
      if (drop.pictures) {
        // Each picture is a version, shown large instead of a 3D view.
        item.versions.push({
          label: images.length === 1 ? "Picture" : f.replace(/\.[^.]+$/, ""),
          kind: "image",
          file,
          bytes: bytes.length,
          updated: new Date(fs.statSync(full).mtimeMs).toISOString(),
          source: path.join(...drop.rel, f),
        });
      } else {
        item.images.push({ file, name: f });
      }
    }
    dropped++;
  }

  // Stable order: folders by the catalog's order, then by name.
  const order = (name, level) => {
    if (level === 0) {
      const i = catalog.folders.indexOf(name);
      return i === -1 ? 999 : i;
    }
    const t = catalog.tiers.indexOf(name);
    return t === -1 ? 999 : t;
  };
  const folderOrder = {};
  for (const it of items) {
    it.path.forEach((p, level) => {
      const k = it.path.slice(0, level + 1).map((x) => x.toLowerCase()).join("/"); // the viewer's key
      folderOrder[k] = [order(p, level), p.toLowerCase()];
    });
  }
  items.forEach((it, i) => (it.id = `d${i}`));

  const out = {
    builtAt: new Date().toISOString(),
    gameModelsAt: models.exportedAt ?? null,
    folderOrder,
    items,
  };
  fs.writeFileSync(path.join(dataDir, "catalog.js"), `window.DESIGN_CATALOG = ${JSON.stringify(out)};\n`);

  // The viewer itself.
  const viewer = path.join(HERE, "viewer");
  fs.copyFileSync(path.join(viewer, "index.html"), path.join(opts.out, "Design Viewer.html"));
  fs.mkdirSync(path.join(opts.out, "app"), { recursive: true });
  for (const [from, to] of [
    ["dist/viewer.js", "viewer.js"],
    ["dist/draco.js", "draco.js"],
    ["viewer.css", "viewer.css"],
    ["icon.ico", "icon.ico"],
  ]) {
    fs.copyFileSync(path.join(viewer, from), path.join(opts.out, "app", to));
  }

  const versions = items.reduce((n, it) => n + it.versions.length, 0);
  console.log(
    `design viewer: ${items.length} designs (${versions} versions, ${dropped} dropped folders) -> ${path.join(
      opts.out,
      "Design Viewer.html",
    )}`,
  );
}

build(parseArgs(process.argv.slice(2)));
