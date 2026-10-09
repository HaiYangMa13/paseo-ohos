import { cp, mkdtemp, readFile, readdir, rm, stat, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const REPO_ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const SOURCE = path.join(REPO_ROOT, "packages/app/dist");
const TARGET = path.join(REPO_ROOT, "ohos/entry/src/main/resources/rawfile");

/** ArkWeb rawfile URLs need document-relative entry, font and lazy chunk URLs. */
export function localizeAssetPaths(content) {
  return content
    .replace(/((?:src|href)=["'])\/(?!\/)/g, "$1./")
    .replace(/(["'`(])\/(?=(?:_expo|assets)\/)/g, "$1./");
}

/** Only the HTML entry may receive a bootstrap; JS bundles can contain HTML strings. */
export function localizeOhosEntry(html) {
  const localized = localizeAssetPaths(html);
  if (localized.includes('id="paseo-ohos-route-bootstrap"')) return localized;
  if (!localized.includes("<head>")) throw new Error("Expo entry is missing <head>");
  return localized.replace(
    "<head>",
    `<head>
    <script id="paseo-ohos-route-bootstrap">
      if (window.location.protocol === "resource:" && window.location.pathname === "/index.html") {
        window.history.replaceState(null, "", "/" + window.location.search + window.location.hash);
      }
    </script>`,
  );
}

async function localizeDirectory(directory) {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const file = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      await localizeDirectory(file);
    } else if (/\.(?:html|js|css)$/.test(entry.name)) {
      const original = await readFile(file, "utf8");
      const localized = localizeAssetPaths(original);
      if (original !== localized) await writeFile(file, localized);
    }
  }
}

export async function syncOhosWeb() {
  // Validate the export before replacing the currently bundled client.
  const html = await readFile(path.join(SOURCE, "index.html"), "utf8");
  for (const match of html.matchAll(/(?:src|href)=["']\/(?!\/)([^"']+)["']/g)) {
    await stat(path.join(SOURCE, match[1]));
  }
  const temporary = await mkdtemp(path.join(tmpdir(), "paseo-ohos-web-"));
  const staged = path.join(temporary, "rawfile");
  try {
    await cp(SOURCE, staged, { recursive: true });
    await localizeDirectory(staged);
    await writeFile(path.join(staged, "index.html"), localizeOhosEntry(html));
    const manifestFile = path.join(staged, "manifest.json");
    const manifest = JSON.parse(await readFile(manifestFile, "utf8"));
    manifest.start_url = "./index.html";
    manifest.scope = "./";
    await writeFile(manifestFile, `${JSON.stringify(manifest, null, 2)}\n`);
    await rm(TARGET, { recursive: true, force: true });
    // Copy rather than rename: the system temp directory can be on another drive.
    await cp(staged, TARGET, { recursive: true });
    console.log("Synced Expo web export into HarmonyOS rawfile resources.");
  } finally {
    await rm(temporary, { recursive: true, force: true });
  }
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  await syncOhosWeb();
}
