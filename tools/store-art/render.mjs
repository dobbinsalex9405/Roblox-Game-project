// Renders store art: inlines the studio fonts into each source SVG (so the
// committed SVG is self-contained) and rasterises it to PNG with Chromium.
//
//   node tools/store-art/render.mjs            # every job in jobs.json
//   node tools/store-art/render.mjs banner     # jobs whose name contains "banner"
//
// Needs Node 18+ and Playwright with Chromium (`npm i -g playwright` then
// `npx playwright install chromium` on a fresh machine).
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { createRequire } from "node:module";

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "../..");
const require = createRequire(import.meta.url);
const { chromium } = require("playwright");

const FONTS = [
  ["Lilita One", 400, "LilitaOne.ttf"],
  ["Fredoka", 600, "Fredoka-600.ttf"],
  ["Fredoka", 700, "Fredoka-700.ttf"],
];

function fontCss(svg) {
  return FONTS.filter(([family]) => svg.includes(family))
    .map(([family, weight, file]) => {
      const b64 = readFileSync(join(here, "fonts", file)).toString("base64");
      return `@font-face{font-family:'${family}';font-weight:${weight};src:url(data:font/ttf;base64,${b64}) format('truetype');}`;
    })
    .join("");
}

const jobs = JSON.parse(readFileSync(join(here, "jobs.json"), "utf8"));
const filter = process.argv[2];
const browser = await chromium.launch();
const page = await browser.newPage();
for (const job of jobs) {
  if (filter && !job.name.includes(filter)) continue;
  let svg = readFileSync(join(here, "src", job.src), "utf8");
  // <!--INCLUDE:parts/x.svg--> pastes a shared fragment (defs, characters).
  svg = svg.replace(/<!--INCLUDE:([\w./-]+)-->/g, (_, f) => readFileSync(join(here, "src", f), "utf8"));
  svg = svg.replace("/*FONTS*/", fontCss(svg));
  for (const out of job.out) {
    const outPath = join(root, out.path);
    mkdirSync(dirname(outPath), { recursive: true });
    if (out.path.endsWith(".svg")) {
      writeFileSync(outPath, svg);
      continue;
    }
    const [w, h] = out.size;
    await page.setViewportSize({ width: w, height: h });
    await page.setContent(
      `<!doctype html><html><body style="margin:0;background:transparent">` +
        svg.replace("<svg ", `<svg style="display:block;width:${w}px;height:${h}px" `) +
        `</body></html>`,
    );
    await page.evaluate(() => document.fonts.ready);
    await page.waitForTimeout(150);
    await page.screenshot({ path: outPath, omitBackground: true, clip: { x: 0, y: 0, width: w, height: h } });
  }
  console.log("rendered", job.name);
}
await browser.close();
