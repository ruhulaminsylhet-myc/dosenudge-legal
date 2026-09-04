#!/usr/bin/env node
// Generates the Android/iOS platform folders for both Flutter apps and patches
// them with everything this project needs: location + notification permissions,
// photo-library usage strings, and the minSdk that the Firebase SDKs require.
//
// Safe to re-run — every patch checks whether it has already been applied.
//
// Usage:
//   node scripts/setup-flutter-apps.mjs
//   node scripts/setup-flutter-apps.mjs driver_app          # just one app
//   node scripts/setup-flutter-apps.mjs --org=com.yourco    # your bundle ids
//
// --org sets the bundle id prefix, producing com.yourco.taxi.driver and
// com.yourco.taxi.rider. It only applies the first time, when the platform
// folders are created. Defaults to com.example.
//
// Afterwards, run `flutterfire configure` inside each app to generate
// lib/firebase_options.dart (it is gitignored — one per Firebase project).

import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");

const APPS = {
  driver_app: {
    // Drivers stream location while online, so they need background access.
    backgroundLocation: true,
    locationWhenInUse:
      "We use your location to match you with nearby ride requests.",
    locationAlways:
      "We keep sharing your location while you are online so riders can see "
      + "you approaching.",
    photoLibrary:
      "We need access to your photos so you can upload your licence, insurance "
      + "and vehicle documents.",
  },
  rider_app: {
    backgroundLocation: false,
    locationWhenInUse:
      "We use your location to set your pickup point and track your ride.",
    locationAlways: null,
    photoLibrary: null,
  },
};

const ANDROID_PERMISSIONS = [
  "android.permission.INTERNET",
  "android.permission.ACCESS_COARSE_LOCATION",
  "android.permission.ACCESS_FINE_LOCATION",
  "android.permission.POST_NOTIFICATIONS",
];

// Firebase Auth 5.x / Storage 12.x require API 23 as a minimum.
const MIN_SDK = 23;

function run(cmd, args, cwd) {
  execFileSync(cmd, args, { cwd, stdio: "inherit" });
}

function patch(file, apply) {
  if (!existsSync(file)) {
    console.warn(`  ! skipped (not found): ${file}`);
    return;
  }
  const before = readFileSync(file, "utf8");
  const after = apply(before);
  if (after === before) {
    console.log(`  = already up to date: ${file}`);
    return;
  }
  writeFileSync(file, after);
  console.log(`  ✔ patched: ${file}`);
}

function patchAndroidManifest(appDir, config) {
  const file = join(appDir, "android/app/src/main/AndroidManifest.xml");
  patch(file, (xml) => {
    const wanted = [...ANDROID_PERMISSIONS];
    if (config.backgroundLocation) {
      wanted.push("android.permission.ACCESS_BACKGROUND_LOCATION");
      wanted.push("android.permission.FOREGROUND_SERVICE");
      wanted.push("android.permission.FOREGROUND_SERVICE_LOCATION");
    }
    const missing = wanted.filter((p) => !xml.includes(`"${p}"`));
    if (missing.length === 0) return xml;

    const lines = missing
      .map((p) => `    <uses-permission android:name="${p}" />`)
      .join("\n");
    // Permissions belong directly under <manifest>, before <application>.
    return xml.replace(/(\n\s*<application)/, `\n${lines}\n$1`);
  });
}

function patchMinSdk(appDir) {
  for (const name of ["build.gradle.kts", "build.gradle"]) {
    const file = join(appDir, "android/app", name);
    if (!existsSync(file)) continue;
    patch(file, (src) => {
      if (src.includes(`minSdk = ${MIN_SDK}`) || src.includes(`minSdkVersion ${MIN_SDK}`)) {
        return src;
      }
      // Newer templates use the Kotlin DSL (`minSdk = flutter.minSdkVersion`),
      // older ones the Groovy DSL (`minSdkVersion flutter.minSdkVersion`).
      return src
        .replace(/minSdk\s*=\s*flutter\.minSdkVersion/, `minSdk = ${MIN_SDK}`)
        .replace(/minSdkVersion\s+flutter\.minSdkVersion/, `minSdkVersion ${MIN_SDK}`);
    });
    return;
  }
  console.warn("  ! skipped minSdk patch: no android/app/build.gradle[.kts]");
}

// `flutter create --org X` appends the pubspec project name, giving ids like
// com.yourco.taxi.taxi_driver_app. Set the id we actually want instead.
function patchBundleId(appDir, bundleId) {
  for (const name of ["build.gradle.kts", "build.gradle"]) {
    const file = join(appDir, "android/app", name);
    if (!existsSync(file)) continue;
    patch(file, (src) =>
      src
        .replace(/namespace\s*=\s*"[^"]+"/, `namespace = "${bundleId}"`)
        .replace(/namespace\s+"[^"]+"/, `namespace "${bundleId}"`)
        .replace(/applicationId\s*=\s*"[^"]+"/, `applicationId = "${bundleId}"`)
        .replace(/applicationId\s+"[^"]+"/, `applicationId "${bundleId}"`)
    );
    break;
  }

  // Xcode keeps the id in three build configurations, plus the test target
  // which must stay a child of the app's id.
  const pbx = join(appDir, "ios/Runner.xcodeproj/project.pbxproj");
  patch(pbx, (src) =>
    src.replace(
      /PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);/g,
      (_, current) =>
        `PRODUCT_BUNDLE_IDENTIFIER = ${bundleId}${
          current.trim().endsWith(".RunnerTests") ? ".RunnerTests" : ""
        };`
    )
  );
}

// `flutter create` drops in a widget test for the counter template app, which
// references a MyApp class this project doesn't have — it fails `flutter
// analyze` out of the box. Remove it, but only while it is still the untouched
// template, so a real test written later is never deleted.
function removeTemplateTest(appDir) {
  const file = join(appDir, "test/widget_test.dart");
  if (!existsSync(file)) return;
  const src = readFileSync(file, "utf8");
  if (src.includes("MyApp()") && src.includes("Counter increments smoke test")) {
    rmSync(file);
    console.log(`  ✔ removed template test: ${file}`);
  }
}

function patchInfoPlist(appDir, config) {
  const file = join(appDir, "ios/Runner/Info.plist");
  patch(file, (plist) => {
    const entries = [
      ["NSLocationWhenInUseUsageDescription", config.locationWhenInUse],
      ["NSLocationAlwaysAndWhenInUseUsageDescription", config.locationAlways],
      ["NSPhotoLibraryUsageDescription", config.photoLibrary],
    ].filter(([key, value]) => value && !plist.includes(`<key>${key}</key>`));

    if (entries.length === 0) return plist;

    const xml = entries
      .map(([key, value]) => `\t<key>${key}</key>\n\t<string>${value}</string>`)
      .join("\n");
    // Insert just before the closing </dict> of the root dictionary.
    const close = plist.lastIndexOf("</dict>");
    return plist.slice(0, close) + xml + "\n" + plist.slice(close);
  });
}

const args = process.argv.slice(2);
const orgArg = args.find((a) => a.startsWith("--org="));
const ORG = orgArg ? orgArg.slice("--org=".length) : "com.example";
const requested = args.filter((a) => !a.startsWith("--"));
const targets = requested.length > 0 ? requested : Object.keys(APPS);

for (const app of targets) {
  const config = APPS[app];
  if (!config) {
    console.error(`Unknown app "${app}". Expected one of: ${Object.keys(APPS).join(", ")}`);
    process.exit(1);
  }

  const appDir = join(ROOT, "apps", app);
  if (!existsSync(appDir)) {
    console.error(`Missing app directory: ${appDir}`);
    process.exit(1);
  }

  // driver_app -> com.yourco.taxi.driver, rider_app -> com.yourco.taxi.rider
  const bundleSuffix = app.replace("_app", "");
  console.log(`\n== ${app} ==`);
  if (!existsSync(join(appDir, "android"))) {
    console.log(`  Generating platform folders (${ORG}.taxi.${bundleSuffix})…`);
    run(
      "flutter",
      ["create", ".", "--platforms=android,ios", "--org", `${ORG}.taxi`],
      appDir
    );
  } else {
    console.log("  Platform folders already exist.");
  }

  patchAndroidManifest(appDir, config);
  patchMinSdk(appDir);
  patchBundleId(appDir, `${ORG}.taxi.${bundleSuffix}`);
  patchInfoPlist(appDir, config);
  removeTemplateTest(appDir);

  console.log("  Fetching packages…");
  run("flutter", ["pub", "get"], appDir);
}

console.log(`
Done. Next, for each app:

  cd apps/<app> && flutterfire configure

That writes lib/firebase_options.dart (gitignored). Give the driver and rider
apps different bundle ids, e.g. com.yourco.taxi.driver and com.yourco.taxi.rider,
inside the same Firebase project.
`);
