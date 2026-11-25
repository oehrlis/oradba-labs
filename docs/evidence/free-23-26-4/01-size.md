# Claim 1 - Image size

Claim in the draft: compressed size 3.53 -> 1.92 GB (arm64) and 3.71 -> 2.11 GB (amd64). Assumption to check:
"the 1.6 GB are the seed files".

- Date: 2026-11-25 (gate, online)
- Images: `free:23.26.3.0` index `sha256:f988b0c04c4c386cd306a2a914c0d7a9702d83acc31b064a28ad8eb6278a8fba`,
  `free:23.26.4.0` index `sha256:f5a1791bf5628fd1a97e07584ff5ac5537da5021c23e70f5083f48c8fcd6476e` (= `latest`)

## Compressed (registry manifests, both architectures)

Command: `docker manifest inspect --verbose container-registry.oracle.com/database/free:<tag>`, sum of the layer
sizes (`raw/manifest-*.json`, `raw/layers-compressed.txt`).

| Arch | 23.26.3.0 bytes | 23.26.4.0 bytes | Difference |
| --- | --- | --- | --- |
| arm64 | 3 527 716 613 | 1 916 520 018 | 1 611 196 595 |
| amd64 | 3 708 609 082 | 2 110 381 717 | 1 598 227 365 |

The draft's numbers are decimal GB and match. The registry page shows the same values in GiB (3.28 -> 1.78 arm64,
1.96 amd64) - same size, different unit.

## Uncompressed (arm64, file system inside the image)

Command: `docker run --rm --network none --entrypoint /bin/bash <image> -c 'du -xk --max-depth=1 <path>'` per path,
joined in `raw/du-diff-kb.tsv`; listing in `raw/fs-probe-local.txt`.

| Path | 23.26.3.0 KiB | 23.26.4.0 KiB | What it is |
| --- | --- | --- | --- |
| `/` (whole rootfs) | 8 845 568 | 3 883 128 | 8.4 GiB -> 3.7 GiB |
| `/opt/oracle/oradata` | 4 111 408 | 4 | prebuilt DB unpacked (23.26.3) vs. empty (23.26.4) |
| `/opt/oracle/prebuilt-oradata.tar.gz` | - | 481 436 | the same prebuilt DB, packed (23.26.4 only) |
| `/var/cache/dnf` | 796 980 | 0 | dnf metadata cache left in the 23.26.3 image |
| `.../assistants/dbca/templates` | 428 308 | 4 | `FREE_Database.dbc` + seed files (claim 2) |
| `.../dbhomeFree/sqlcl` | 158 392 | 133 212 | -25 MB |
| `/opt/oracle/diag` | 22 372 | 0 | build-time diag |

`docker images` reports 13.1 GB / 5.91 GB. These numbers count layers that overwrite each other, not the file
system - not used here.

## What the compressed difference consists of

Estimate: gzip of the removed paths inside 23.26.3.0 (`tar cf - <path> | gzip -c | wc -c`,
`raw/gzip-estimate-23.26.3.0.txt`). Docker also uses gzip, but the layer boundaries differ, so this is an
approximation.

| Part (arm64) | Compressed, approx. |
| --- | --- |
| dnf cache (`/var/cache/dnf`), only in 23.26.3 | 672 MB |
| DBCA template + seed files, only in 23.26.3 | 386 MB |
| prebuilt DB: unpacked layer 483 MB vs. `prebuilt-oradata.tar.gz` 493 MB | about 0 |
| rest (OL 8.10 -> OL 9.8 base, packages, sqlcl, diag) - not broken down | about 550 MB |
| **total difference** | **1 611 MB** |

## Result

- Compressed sizes in the draft: **confirmed** (decimal GB, both architectures)
- "The 1.6 GB are the seed files": **refuted** - seed files are about 0.39 GB compressed (0.44 GB uncompressed).
  The largest single part is a dnf cache that 23.26.3 shipped by mistake. The prebuilt database is still in the
  image, packed as a tar.gz instead of an unpacked layer
- About 0.55 GB of the difference is not broken down: **open** (assumption: different base image and package set)

Side note: `INSTALL_FILE_1` in the 23.26.4.0 environment names
`oracle-ai-database-free-26ai-23.26.3-1.el9.aarch64.rpm`, while `sqlplus -v` reports `23.26.4.0.0`
(`raw/fs-probe-local.txt`). The binaries are 23.26.4, the env variable is out of date.
