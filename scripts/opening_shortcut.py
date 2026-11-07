"""Sign or verify the iPhone Duo opening automation using Apple's macOS tools."""
import argparse
import plistlib
import struct
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
NAME = "Count iPhone Duo Openings"
SOURCE = ROOT / "shortcuts" / (NAME + ".plist")
BUNDLED = ROOT / "Resources" / (NAME + ".shortcut")


def check_workflow(expected: dict, actual: dict) -> None:
    if actual.get("WFWorkflowTriggers") != expected["WFWorkflowTriggers"]:
        raise ValueError("The signed file lost or changed the opening trigger. Use a Shortcuts signer that preserves iOS 27 automations.")
    # Apple's exporter stamps its own client version. All other fields, including
    # the sole action, trigger parameters and import questions, must survive.
    if ({k: v for k, v in actual.items() if k != "WFWorkflowClientVersion"}
            != {k: v for k, v in expected.items() if k != "WFWorkflowClientVersion"}):
        raise ValueError("The signed workflow differs from the reviewed template.")


def verify(signed: Path) -> None:
    data = signed.read_bytes()
    if len(data) < 12 or len(data) > 1024 * 1024:
        raise ValueError("Invalid shortcut file size.")
    magic, profile, length = struct.unpack_from("<4sII", data)
    if magic != b"AEA1" or profile != 0 or length > len(data) - 12:
        raise ValueError("Expected an Apple signed-only archive.")
    chain = plistlib.loads(data[12:12 + length])["SigningCertificateChain"]
    if len(chain) < 2:
        raise ValueError("Missing shortcut signing certificate chain.")

    with tempfile.TemporaryDirectory() as temp:
        work = Path(temp)
        certs = []
        for index, der in enumerate(chain[:-1]):
            cert = work / f"certificate-{index}.der"
            cert.write_bytes(der)
            certs.extend(["-c", str(cert)])
        # Let the system choose the trusted root; do not trust an archive-supplied root.
        subprocess.run(["/usr/bin/security", "verify-cert", "-q", "-L", "-p", "basic", *certs], check=True)
        key = work / "public.pem"
        with key.open("wb") as output:
            subprocess.run(["/usr/bin/openssl", "x509", "-inform", "DER", "-in", work / "certificate-0.der",
                            "-pubkey", "-noout"], stdout=output, check=True)
        staged = work / "candidate.shortcut"
        staged.write_bytes(data)
        archive = work / "payload.aar"
        subprocess.run(["/usr/bin/aea", "decrypt", "-i", staged, "-o", archive, "-sign-pub", key], check=True)
        entries = subprocess.check_output(["/usr/bin/aa", "list", "-i", archive], text=True).splitlines()
        if [entry for entry in entries if entry] != ["Shortcut.wflow"]:
            raise ValueError("Expected exactly one workflow in the signed archive.")
        extracted = work / "contents"
        extracted.mkdir()
        subprocess.run(["/usr/bin/aa", "extract", "-i", archive, "-d", extracted], check=True)
        workflow = extracted / "Shortcut.wflow"
        if workflow.is_symlink() or not workflow.is_file():
            raise ValueError("The signed workflow must be a regular file.")
        check_workflow(plistlib.loads(SOURCE.read_bytes()), plistlib.loads(workflow.read_bytes()))


def sign(destination: Path) -> None:
    # Stage on the same volume; a failed signer or verification keeps any last good file.
    with tempfile.TemporaryDirectory(dir=destination.parent) as temp:
        work = Path(temp)
        unsigned = work / (NAME + ".shortcut")
        unsigned.write_bytes(plistlib.dumps(plistlib.loads(SOURCE.read_bytes()), fmt=plistlib.FMT_BINARY))
        candidate = work / "signed.shortcut"
        subprocess.run(["/usr/bin/shortcuts", "sign", "--mode", "anyone",
                        "--input", unsigned, "--output", candidate], check=True)
        verify(candidate)
        candidate.replace(destination)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("operation", choices=["sign", "verify"])
    parser.add_argument("file", nargs="?", type=Path, default=BUNDLED)
    args = parser.parse_args()
    try:
        (sign if args.operation == "sign" else verify)(args.file)
    except (ValueError, KeyError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
    print(f"Verified the signed opening automation: {args.file}")
