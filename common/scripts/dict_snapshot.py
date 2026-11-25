#!/usr/bin/env python3
"""Convert the tagged sqlplus lines of common/sql/dict_snapshot.sql into the
oracle-check snapshot JSON (keys: version, source, created, objects, synonyms,
members, columns, fixed, params, obsolete, ora, banner, patches, lab).

Mirrors parse_snapshot() of aitk oracle-check (oradba_aitk/oracle_check/dictionary.py).
Usage: dict_snapshot.py <tagged.txt> <ora_codes.txt> <source> <out.json> [key=value ...]
The key=value pairs end up in the "lab" object. Standard library only.
"""

import json
import sys
from datetime import datetime


def main() -> int:
    tagged, ora_codes, source, out = sys.argv[1:5]
    lab = dict(a.split("=", 1) for a in sys.argv[5:])
    snap = {
        "version": "", "source": source, "created": datetime.now().isoformat(timespec="seconds"),
        "objects": {}, "synonyms": {}, "members": {}, "columns": {}, "fixed": [], "params": [],
        "obsolete": [], "ora": [], "banner": "", "patches": [], "lab": lab,
    }
    members: dict[str, set[str]] = {}
    with open(tagged, encoding="utf-8", errors="replace") as fh:
        lines = fh.read().splitlines()
    errors = [ln for ln in lines if ln.startswith(("ORA-", "SP2-"))]
    if errors:
        print("snapshot query failed: " + "; ".join(errors[:3]), file=sys.stderr)
        return 1
    for line in lines:
        tag, _, rest = line.partition("|")
        f = rest.split("|")
        if tag == "V":
            snap["version"] = rest.strip()
        elif tag == "O" and len(f) == 3:
            snap["objects"].setdefault(f[1], []).append([f[0], f[2]])
        elif tag == "S" and len(f) == 4:
            snap["synonyms"][f[1]] = [f[2], f[3]]
        elif tag in ("P", "M") and len(f) == 3 and f[2]:
            members.setdefault(f"{f[0]}.{f[1]}", set()).add(f[2].upper())
        elif tag == "C" and len(f) == 3:
            snap["columns"].setdefault(f"{f[0]}.{f[1]}", []).append(f[2])
        elif tag == "F":
            snap["fixed"].append(rest.strip())
        elif tag == "R":
            snap["params"].append(rest.strip().upper())
        elif tag == "X":
            snap["obsolete"].append(rest.strip().upper())
        elif tag == "B":
            snap["banner"] = " ".join(rest.split())
        elif tag == "U" and len(f) >= 5:
            snap["patches"].append([f[0], f[1], f[2], f[3], "|".join(f[4:]).strip()])
    if not snap["version"] or not snap["objects"]:
        print("snapshot query returned no dictionary rows", file=sys.stderr)
        return 1
    snap["members"] = {k: sorted(v) for k, v in members.items()}
    with open(ora_codes, encoding="utf-8") as fh:
        snap["ora"] = sorted({c for c in fh.read().split() if c.isdigit()})
    with open(out, "w", encoding="utf-8") as fh:
        json.dump(snap, fh)
    return 0


if __name__ == "__main__":
    sys.exit(main())
