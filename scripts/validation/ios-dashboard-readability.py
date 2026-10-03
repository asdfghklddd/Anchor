#!/usr/bin/env python3
"""Check dashboard progress in real light/dark simulator appearance with disposable data.

Requires a booted simulator with the Anchor iOS debug app already installed.
Example: python3 scripts/validation/ios-dashboard-readability.py --device SIMULATOR_UUID
Restores system appearance and removes imported data; keeps logs and xcresult bundles.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
STORE_ID = "CA720001-7215-40E0-8B0B-000000000100"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", required=True)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--derived-data", default="/tmp/anchor-dashboard-ios-build")
    args = parser.parse_args()
    output = (args.output or Path(tempfile.mkdtemp(prefix="anchor-readability-results-"))).resolve()
    output.mkdir(parents=True, exist_ok=True)
    if any((output / (mode + ".xcresult")).exists() for mode in ("light", "dark")):
        parser.error("Choose a new output directory; existing results are preserved.")

    def store():
        container = subprocess.check_output([
            "xcrun", "simctl", "get_app_container", args.device, "com.andywang.anchor", "data"
        ], text=True).strip()
        return Path(container) / "tmp/AnchorUITests" / STORE_ID

    initial = store()
    if initial.exists():
        parser.error("This review store already exists; finish its owning run first.")
    original = subprocess.check_output([
        "xcrun", "simctl", "ui", args.device, "appearance"
    ], text=True).strip()
    owned = set()
    with tempfile.TemporaryDirectory(prefix="anchor-readability-data-") as fixture:
        with (output / "data-journey.log").open("w") as log:
            subprocess.run([
                "swift", "test", "--scratch-path", "/tmp/anchor-workflow-build",
                "--filter", "DashboardReadabilityJourneyTests"
            ], cwd=ROOT / "Packages/AnchorKit",
                env=dict(os.environ, ANCHOR_READABILITY_REVIEW_EXPORT=fixture),
                stdout=log, stderr=subprocess.STDOUT, check=True, timeout=180)
        try:
            initial.mkdir(parents=True)
            owned.add(initial)
            shutil.copyfile(Path(fixture) / "session-repository.json", initial / "session-repository.json")
            for mode in ("light", "dark"):
                subprocess.run(["xcrun", "simctl", "ui", args.device, "appearance", mode], check=True)
                result = output / (mode + ".xcresult")
                with (output / (mode + ".log")).open("w") as log:
                    subprocess.run([
                        "xcodebuild", "-project", "Anchor.xcodeproj", "-scheme", "Anchor iOS",
                        "-configuration", "Debug", "-destination", "platform=iOS Simulator,id=" + args.device,
                        "-parallel-testing-enabled", "NO", "-collect-test-diagnostics", "never",
                        "-derivedDataPath", args.derived_data, "-resultBundlePath", str(result),
                        "-only-testing:AnchorIOSUITests/DashboardReadabilityUITests",
                        "CODE_SIGNING_ALLOWED=NO", "test"
                    ], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=360)
                summary = json.loads(subprocess.check_output([
                    "xcrun", "xcresulttool", "get", "test-results", "summary", "--path", str(result)
                ], text=True))
                if summary.get("passedTests") != 1 or summary.get("skippedTests") != 0:
                    raise RuntimeError(mode + " readability test must pass without skipping.")
                print(mode + ": passed")
        finally:
            try:
                subprocess.run(["xcrun", "simctl", "ui", args.device, "appearance", original], check=True)
            finally:
                try:
                    if owned:
                        owned.add(store())  # Xcode may migrate the app to a new container.
                finally:
                    for directory in owned:
                        if directory.exists():
                            shutil.rmtree(directory)
            print("Removed isolated dashboard data. Results:", output)


if __name__ == "__main__":
    main()
