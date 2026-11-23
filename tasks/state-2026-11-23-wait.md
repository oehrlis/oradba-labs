# Session State: oradba-labs - 2026-11-23 (wait)

Supersedes `state-2026-11-23.md`.

Naechster Schritt: Entscheid 26ai-Image (Free 23.26.4.0 ohne dbca-Template), danach base26 rebuild ab Di 10:00

## Done this session

- `labctl wait_ready` erkennt gescheiterte Starts (`c50bf24`): Start vs. Erstellung je DB, Abbruch mit
  Alert-Log-Tail bei `WAS NOT SUCCESSFUL` oder (vorhandene Daten) nicht healthy nach `START_TIMEOUT` 300 s;
  base26 mit provoziertem ORA-16038: Abbruch nach 11 s. `DRY_RUN` akzeptiert `TRUE|1|yes` / `FALSE|0|no`
- PR #1 (Lab audit26) per Rebase gemergt (`72df000`, `d617306`), Branch lokal + origin geloescht;
  ora-db-audit-eng nutzt audit26 von main (Purge-Test due 2026-11-27)
- SCOTT + TVD_HR in `LABPDB1` von base19 und base26 (`5e06107`, Hooks 16/17, Entscheid Stefan); base19
  rebuild: verify SCOTT, TVD_HR, HR OK. base26 noch nicht neu erstellt (MFA-Demo)
- seclab samt Daten geloescht (Entscheid Stefan), Platte 92 % / 37 GB frei; `audit26`-Daten = Lab audit26
- Free 23.26.4.0 (`= latest`) geprueft und verworfen (`11983d6`, `49f6c9d`): kein dbca-Template, entpackt
  `prebuilt-oradata.tar.gz` in das leere Bind-Verzeichnis, `setup/` laeuft nie; `command: runOracle.sh`
  scheitert mit DBT-10508. Widerspricht der Registry-Doku. Umstellung zurueckgenommen, alle 26ai-Labs auf
  `oracle-free-labs` (23.26.3)
- Zwischenfall audit26: fehlende `lab.env` im Haupt-Checkout -> neue aus geaenderter Vorlage, ein Start unter
  23.26.4 auf 23.26.3-Daten; Dictionary geprueft (VALID, kein datapatch), echte `lab.env` aus dem Worktree
  kopiert, Lesson in `tasks/lessons.md`
- Task "Mechanik v0.2.0" in `areas/oci-labs.md` abgehakt; Docker-RAM bleibt 16 GB
- PKM: Tasks Chris Saxon (UKOUG, due 2026-11-25) und Mail an Gerald Venzl / Martin Bach (due 2026-11-27),
  Entwurf `~/notes/prompts/free-23-26-4-image.md`

## Pendenzen

<!-- markdownlint-disable MD013 MD060 -->
| # | Was | Bis | Wer | Status |
| --- | --- | --- | --- | --- |
| 1 | Entscheid 26ai: Prebuilt-DB + idempotente Startup-Hooks oder bei 23.26.3 bleiben bis oradba-docker (labs-M2) | - | Stefan | offen |
| 2 | Chris Saxon an der UKOUG zum Free-Image 23.26.4.0 fragen | 2026-11-25 | Stefan | offen |
| 3 | Mail an Gerald Venzl / Martin Bach (Entwurf in `~/notes/prompts/free-23-26-4-image.md`) | 2026-11-27 | Stefan | offen |
| 4 | base26 rebuild + `verify.sh` mit `LABPDB1:SCOTT,TVD_HR` - base26 belegt bis Di 10:00 (MFA-Demo) | 2026-11-25 | Session | wartet |
| 5 | audit26 auf neues Image erst nach Purge-Test, auf Zeichen von ora-db-audit-eng | 2026-11-27 | extern | wartet |
| 6 | seclab neu erstellen (`make up LAB=seclab`) | - | Session | offen |
<!-- markdownlint-restore -->

## Open (P1)

- [ ] Entscheid 26ai-Image (Pendenz 1) - blockiert die Umstellung von base26, audit26, seclab

## Open (P2)

- [ ] base26 rebuild + verify-Erwartung SCOTT/TVD_HR (ab Di 2026-11-24 10:00)
- [ ] seclab neu erstellen
- [ ] Lab-Images auf oradba-docker umstellen, Free-Version pinnen (labs-M2; oradba-docker gibt es noch nicht)

## To resume

```bash
cd ~/Repos/own/oehrlis/oradba-labs
sed -n '/26ai-Labs auf Free 23.26.4/,/seclab neu erstellen/p' tasks/open-work.md
docker ps --format '{{.Names}} {{.Status}}'
```
