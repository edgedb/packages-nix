# Queries packages.edgedb.com and prints list of edgedb-server sources
# that can be copy pasted into the flake.nix.
#
# Run with:
#
# $ python lookup_packages_edgedb_com.py
#

import requests
from typing import Tuple, Any, Callable

def main():
    platforms = [
        {"nix": "x86_64-linux", "edgedb": "x86_64-unknown-linux-gnu"},
        {"nix": "aarch64-linux", "edgedb": "aarch64-unknown-linux-gnu"},
        {"nix": "x86_64-darwin", "edgedb": "x86_64-apple-darwin"},
        {"nix": "aarch64-darwin", "edgedb": "aarch64-apple-darwin"},
    ]

    r = "{\n"
    r += "  edgedb-server = {\n"
    r += generate_artifacts("edgedb-server", "", platforms)
    r += "  };\n"
    r += "  edgedb-server-nightly = {\n"
    r += generate_artifacts("edgedb-server", ".nightly", platforms)
    r += "  };\n"
    r += "}\n"
    print(r)

def find_most_recent(basename, packages) -> Tuple[int, int, int]:
    major = 0
    minor = 0
    revision = 0
    for p in packages:
        if p["basename"] != basename:
            continue

        if p["version_details"]["major"] > major:
            major = p["version_details"]["major"]
            minor = 0
            revision = 0

        if p["version_details"]["minor"] > minor:
            minor = p["version_details"]["minor"]
            revision = 0

        r = int(p["version_details"]["metadata"]["build_revision"])
        if r > revision:
            revision = r
    return (major, minor, revision)


def package_selector(basename, version) -> Callable[[Any], bool]:
    def sel(p) -> bool:
        return (
            p["basename"] == basename
            and p["version_details"]["major"] == version[0]
            and p["version_details"]["minor"] == version[1]
            and p["version_details"]["metadata"]["build_revision"] == str(version[2])
        )

    return sel


def install_ref_selector(i) -> bool:
    return i["encoding"] == "zstd"


def generate_artifacts(basename: str, channel: str, platforms) -> str:
    r = ""
    
    for platform in platforms:
        res = requests.get(
            f"https://packages.edgedb.com/archive/.jsonindexes/{platform['edgedb']}{channel}.json"
        )
        packages = res.json()["packages"]
        version = find_most_recent(basename, packages)
        package = next(filter(package_selector(basename, version), packages))

        install_ref = next(filter(install_ref_selector, package["installrefs"]))

        url = "https://packages.edgedb.com" + install_ref["ref"]
        sha256 = install_ref["verification"]["sha256"]

        r += (
            '    ' + platform["nix"] + " = {\n"
            f'      url = "{url}";\n'
            f'      sha256 = "{sha256}";\n'
            "    };\n"
        )
    return r

main()
