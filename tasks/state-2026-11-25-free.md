# State 2026-11-25 - Free 23.26.4 evidence (gate done)

Re-entry: evaluate `raw/`, then write the report and the mail.

## Done (gate, online)

- Evidence in `docs/evidence/free-23-26-4/` (README with status table, one file per claim, `raw/`), commit
  `docs(evidence): free 23.26.4 image analysis - gate phase` on `main`, **not pushed**
- `collect.sh` (phases registry / static / runtime): shellcheck clean, dry-run and smoke test `--only t0` green,
  registry phase re-run online
- Key findings: deliberate redesign, not a broken build (new `startPrebuilt.sh`, `configurePrebuiltPdb.sh`
  "Since: September, 2026"); prebuilt DB as tar.gz; `ORACLE_CHARACTERSET` = PDB-only `INTERNAL_CONVERT`;
  failing startup script stops the container; create path without template (SID FREE) or response template
  (other SID); registry doc + GitHub still describe 23.26.3; size difference = dnf cache 0.67 GB + seed 0.39 GB and
  about 0.55 GB not broken down

## Next

1. Flight (Stefan, offline, power + lid open, about 1-2 h):

   ```bash
   cd ~/Repos/own/oehrlis/oradba-labs && caffeinate -dims docs/evidence/free-23-26-4/collect.sh --phase runtime --yes 2>&1 | tee .work/free-23-26-4/collect.log
   ```

2. Online (`forge resume oradba-labs`): read `raw/runtime-summary.tsv` and `raw/rt-*.txt`, set the open rows in
   `docs/evidence/free-23-26-4/README.md` and `02`-`04` to confirmed/refuted, write `mail-draft.md` (English,
   short, two `docker run` lines + output) or recommend documentation feedback only, update
   `tasks/open-work.md` (decision 26ai image), commit `docs(evidence): free 23.26.4 runtime results`
3. If a test failed or timed out: rerun only that test, e.g. `collect.sh --phase runtime --only t2 --yes`;
   leftovers: `collect.sh --delete`
