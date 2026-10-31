# -*- coding: utf-8 -*-
"""Patch the Flutter-generated Android Gradle file to use a stable release keystore.

The keystore and android/key.properties are written by CI (from GitHub Secrets,
or generated ephemerally for the first build). Run after:
flutter create . --project-name brew_helper --org com.sunliangyu
"""
from __future__ import annotations

import re
from pathlib import Path

GRADLE = Path("android/app/build.gradle")
GRADLE_KTS = Path("android/app/build.gradle.kts")


def patch_groovy(text: str) -> str:
    if "keystoreProperties" not in text:
        header = (
            "def keystoreProperties = new Properties()\n"
            "def keystorePropertiesFile = rootProject.file('key.properties')\n"
            "if (keystorePropertiesFile.exists()) {\n"
            "    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))\n"
            "}\n\n"
        )
        if "\nandroid {" not in text:
            raise SystemExit("cannot find android block in android/app/build.gradle")
        # Gradle only allows plugins {} before other statements; put the
        # keystore loading right before android {}, after plugins {}.
        text = text.replace("\nandroid {", "\n" + header + "android {", 1)
    if "signingConfigs {" not in text:
        block = (
            "    signingConfigs {\n"
            "        release {\n"
            "            keyAlias keystoreProperties['keyAlias']\n"
            "            keyPassword keystoreProperties['keyPassword']\n"
            "            storeFile file(keystoreProperties['storeFile'])\n"
            "            storePassword keystoreProperties['storePassword']\n"
            "        }\n"
            "    }\n"
        )
        if "    buildTypes {" not in text:
            raise SystemExit("cannot find buildTypes block in android/app/build.gradle")
        text = text.replace("    buildTypes {", block + "    buildTypes {", 1)
    # Replace only the release signing config, not the debug one.
    text2, n = re.subn(
        r"(release\s*\{[^}]*?signingConfig\s*=?\s*)signingConfigs\.debug",
        r"\1signingConfigs.release",
        text,
        count=1,
        flags=re.S,
    )
    if n == 0:
        # Template may have a bare signingConfig line inside release; fall back to a
        # targeted replace in the release block.
        text2 = re.sub(
            r"(release\s*\{[^}]*?)(signingConfig\s*=?\s*[^\n]+)",
            r"\1signingConfig signingConfigs.release",
            text,
            count=1,
            flags=re.S,
        )
        if text2 == text:
            raise SystemExit("cannot find release signingConfig line")
    return text2


def patch_kts(text: str) -> str:
    if "signingConfigs" not in text:
        block = (
            "    signingConfigs {\n"
            "        create(\"release\") {\n"
            "            keyAlias = keystoreProperties[\"keyAlias\"] as String\n"
            "            keyPassword = keystoreProperties[\"keyPassword\"] as String\n"
            "            storeFile = file(keystoreProperties[\"storeFile\"] as String)\n"
            "            storePassword = keystoreProperties[\"storePassword\"] as String\n"
            "        }\n"
            "    }\n"
        )
        if "    buildTypes {" not in text:
            raise SystemExit("cannot find buildTypes block in build.gradle.kts")
        text = text.replace("    buildTypes {", block + "    buildTypes {", 1)
    text = re.sub(
        r"(getByName\(\"release\"\)\s*\{[^}]*?signingConfig\s*=\s*)signingConfigs\.getByName\(\"debug\"\)",
        r"\1signingConfigs.getByName(\"release\")",
        text,
        count=1,
        flags=re.S,
    )
    return text


def main() -> int:
    if GRADLE.exists():
        text = GRADLE.read_text(encoding="utf-8")
        GRADLE.write_text(patch_groovy(text), encoding="utf-8")
        print("patched android/app/build.gradle")
        return 0
    if GRADLE_KTS.exists():
        text = GRADLE_KTS.read_text(encoding="utf-8")
        GRADLE_KTS.write_text(patch_kts(text), encoding="utf-8")
        print("patched android/app/build.gradle.kts")
        return 0
    raise SystemExit("android/app/build.gradle(.kts) not found")


if __name__ == "__main__":
    raise SystemExit(main())
