import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import { runInNewContext, Script } from "node:vm";
import { localizeAssetPaths, localizeOhosEntry } from "./sync-ohos-web.mjs";

test("localizes the entry page, lazy chunks and font assets", () => {
  assert.equal(
    localizeAssetPaths(
      '<script src="/_expo/main.js"></script><link href="/favicon.ico">\n{"chunk":"/_expo/chunk.js","font":"/assets/font.woff2"}\nurl(/assets/font.woff2)',
    ),
    '<script src="./_expo/main.js"></script><link href="./favicon.ico">\n{"chunk":"./_expo/chunk.js","font":"./assets/font.woff2"}\nurl(./assets/font.woff2)',
  );
});

test("does not rewrite external URLs or already relative assets", () => {
  const input =
    '<script src="https://example.com/_expo/main.js"></script><link href="//example.com/a.css">{"chunk":"./_expo/main.js","font":"../assets/font.woff2"}';
  assert.equal(localizeAssetPaths(input), input);
});

test("never injects an HTML bootstrap into JavaScript containing HTML strings", () => {
  const input = 'const template = "<html><head></head><body></body></html>";';
  assert.equal(localizeAssetPaths(input), input);
  assert.doesNotThrow(() => new Script(localizeAssetPaths(input)));
});

test("injects entry bootstrap before scripts and remains idempotent", () => {
  const input = '<html><head><script src="/_expo/main.js"></script></head></html>';
  const localized = localizeOhosEntry(input);
  assert.ok(
    localized.indexOf('id="paseo-ohos-route-bootstrap"') <
      localized.indexOf('src="./_expo/main.js"'),
  );
  assert.equal(localizeOhosEntry(localized), localized);
  assert.throws(() => localizeOhosEntry("<html></html>"), /missing <head>/);
});

test("source and fallback bootstraps canonicalize only the rawfile entry and preserve query/hash", () => {
  const source = readFileSync(
    new URL("../packages/app/public/index.html", import.meta.url),
    "utf8",
  );
  const fallback = localizeOhosEntry("<html><head></head></html>");
  for (const html of [source, fallback]) {
    const script = html.match(/<script id="paseo-ohos-route-bootstrap">([\s\S]*?)<\/script>/)?.[1];
    assert.ok(script, "bootstrap must be present");
    for (const [protocol, pathname, expected] of [
      ["resource:", "/index.html", "/?test=1#anchor"],
      ["resource:", "/", null],
      ["resource:", "/h/host/agent/id", null],
      ["https:", "/index.html", null],
      ["http:", "/h/host/workspace/id", null],
      ["file:", "/index.html", null],
    ]) {
      const calls = [];
      const window = {
        location: { protocol, pathname, search: "?test=1", hash: "#anchor" },
        history: { replaceState: (...args) => calls.push(args) },
      };
      runInNewContext(script, { window });
      assert.equal(calls.length, expected === null ? 0 : 1);
      if (expected !== null) assert.equal(calls[0][2], expected);
    }
  }
});

test("localization is idempotent", () => {
  const localized = localizeAssetPaths('{"chunk":"/_expo/main.js"}');
  assert.equal(localizeAssetPaths(localized), localized);
});
