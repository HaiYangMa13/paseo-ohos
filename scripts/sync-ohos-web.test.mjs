import assert from "node:assert/strict";
import { test } from "node:test";
import { localizeAssetPaths } from "./sync-ohos-web.mjs";

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

test("localization is idempotent", () => {
  const localized = localizeAssetPaths('{"chunk":"/_expo/main.js"}');
  assert.equal(localizeAssetPaths(localized), localized);
});
