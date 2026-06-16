# Determine if all of the given packages are installed.

# Copyright 2025, The MathWorks, Inc.

from importlib.util import find_spec
import sys

def is_installed(pkg) -> bool:
    return find_spec(pkg) is not None

installed = False

if len(sys.argv) > 1:
    installed = [ is_installed(pkg) for pkg in sys.argv[1:] ]

if all(installed):
    print("Ready for mayhem!")
else:
    missing = [pkg for pkg, mask in zip(sys.argv[1:], installed) if mask == False]
    for pkg in missing:
        print(f"Missing: {pkg}")
        