#!/usr/bin/env node
// Generates the Android/iOS platform folders for both Flutter apps and patches
// them with everything this project needs: location + notification permissions,
// photo-library usage strings, and the minSdk that the Firebase SDKs require.
//
// Safe to re-run — every patch checks whether it has already been applied.
//
// Usage:
//   node scripts/setup-flutter-apps.mjs
//   node scripts/setup-flutter-apps.mjs driver_app    # just one app
//
// Afterwards, run `flutterfire configure` inside each app to generate
// lib/firebase_options.dart (it is gitignored — one per Firebase project).

import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
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

const requested = process.argv.slice(2);
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

  console.log(`\n== ${app} ==`);
  if (!existsSync(join(appDir, "android"))) {
    console.log("  Generating platform folders…");
    run("flutter", ["create", ".", "--platforms=android,ios"], appDir);
  } else {
    console.log("  Platform folders already exist.");
  }

  patchAndroidManifest(appDir, config);
  patchMinSdk(appDir);
  patchInfoPlist(appDir, config);

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
