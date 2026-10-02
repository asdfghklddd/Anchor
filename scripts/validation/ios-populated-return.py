#!/usr/bin/env python3
"""Review return data in an installed iOS simulator app using disposable stores.

Example: python3 scripts/validation/ios-populated-return.py --device SIMULATOR_UUID
Requires the Anchor iOS debug app already installed on that booted simulator.
All generated event data is removed; logs and the xcresult remain for inspection.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
STORE_IDS = ("8EAB749A-9806-4D96-9577-10AA97049D4C", "8EAB749A-9806-4D96-9577-10AA97049D4D")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", required=True)
    parser.add_argument("--output", type=Path, default=None)
    parser.add_argument("--derived-data", default="/tmp/anchor-dashboard-ios-build")
    args = parser.parse_args()
    output = (args.output or Path(tempfile.mkdtemp(prefix="anchor-return-review-results-"))).resolve()
    output.mkdir(parents=True, exist_ok=True)
    result = output / "review.xcresult"
    if result.exists():
        parser.error("Choose a new output directory; existing results are preserved.")
    container = Path(subprocess.check_output([
        "xcrun", "simctl", "get_app_container", args.device, "com.andywang.anchor", "data"
    ], text=True).strip())
    stores = [container / "tmp/AnchorUITests" / value for value in STORE_IDS]
    if any(path.exists() for path in stores):
        parser.error("A review store already exists; finish its owning run before starting another.")
    owned = []
    with tempfile.TemporaryDirectory(prefix="anchor-return-review-data-") as fixture:
        environment = dict(os.environ, ANCHOR_RETURN_REVIEW_EXPORT=fixture)
        with (output / "data-journey.log").open("w") as log:
            subprocess.run([
                "swift", "test", "--scratch-path", "/tmp/anchor-workflow-build",
                "--filter", "ReturnDataJourneyTests"
            ], cwd=ROOT / "Packages/AnchorKit", env=environment, stdout=log,
                stderr=subprocess.STDOUT, check=True, timeout=180)
        try:
            for directory in stores:
                directory.mkdir(parents=True)
                owned.append(directory)
                shutil.copyfile(Path(fixture) / "phone.json", directory / "session-repository.json")
            with (output / "ui.log").open("w") as log:
                subprocess.run([
                    "xcodebuild", "-project", "Anchor.xcodeproj", "-scheme", "Anchor iOS",
                    "-configuration", "Debug", "-destination", "platform=iOS Simulator,id=" + args.device,
                    "-parallel-testing-enabled", "NO", "-collect-test-diagnostics", "never",
                    "-derivedDataPath", args.derived_data, "-resultBundlePath", str(result),
                    "-only-testing:AnchorIOSUITests/PopulatedReturnUITests",
                    "CODE_SIGNING_ALLOWED=NO", "test"
                ], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=360)
            summary = json.loads(subprocess.check_output([
                "xcrun", "xcresulttool", "get", "test-results", "summary", "--path", str(result)
            ], text=True))
            if summary.get("passedTests") != 2 or summary.get("skippedTests") != 0:
                raise RuntimeError("Both populated review tests must pass without skipping.")
        finally:
            # Xcode may reinstall the app and migrate its data into a newly
            # named container. Clean the owned IDs there as well as the old path.
            cleanup = set(owned)
            try:
                if owned:
                    current = Path(subprocess.check_output([
                        "xcrun", "simctl", "get_app_container", args.device, "com.andywang.anchor", "data"
                    ], text=True).strip())
                    cleanup.update(current / "tmp/AnchorUITests" / path.name for path in owned)
            finally:
                for directory in cleanup:
                    if directory.exists():
                        shutil.rmtree(directory)
            print("Removed isolated return stores; temporary events are disposed on exit.")
            print("Results:", output)


if __name__ == "__main__":
    main()
