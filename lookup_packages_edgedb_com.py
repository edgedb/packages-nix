# Queries packages.edgedb.com and prints list of edgedb-server sources
# that can be copy pasted into the flake.nix.
#
# Run with:
#
# $ python lookup_packages_edgedb_com.py
#

import requests

platforms = [
    {"nix": "x86_64-linux", "edgedb": "x86_64-unknown-linux-gnu"},
    {"nix": "aarch64-linux", "edgedb": "aarch64-unknown-linux-gnu"},
    {"nix": "x86_64-darwin", "edgedb": "x86_64-apple-darwin"},
    {"nix": "aarch64-darwin", "edgedb": "aarch64-apple-darwin"},
]


def package_selector(p) -> bool:
    return (
        p["basename"] == "edgedb-server"
        and p["version_details"]["major"] == 5
        and p["version_details"]["minor"] == 5
    )


def install_ref_selector(i) -> bool:
    return i["encoding"] == "zstd"


for platform in platforms:
    res = requests.get(
        f"https://packages.edgedb.com/archive/.jsonindexes/{platform['edgedb']}.json"
    )
    packages = res.json()["packages"]
    package = next(filter(package_selector, packages))

    install_ref = next(filter(install_ref_selector, package["installrefs"]))

    url = "https://packages.edgedb.com" + install_ref["ref"]
    sha256 = install_ref["verification"]["sha256"]

    print(
        platform["nix"] + " = {\n"
        f'  url = "{url}";\n'
        f'  sha256 = "{sha256}";\n'
        "};"
    )
