# Session State: oradba-labs - 2026-11-23 (wait)

Supersedes `state-2026-11-23.md`.

Naechster Schritt: Herkunft von `~/oradba-labs-data/audit26` (4.6G, Platte 98 %) klaeren, dann Lab-Images (labs-M2)

## Done this session

- `labctl wait_ready` erkennt gescheiterte Starts (`c50bf24`, gepusht, kein Tag, CHANGELOG Unreleased):
  - `make up` meldet je DB: vorhandene Daten (Start) oder leeres Verzeichnis (Image erstellt die DB),
    gleicher Test wie das Image (`oradata/<SID>/` ora_db, `oradata/.<SID>.created` Free); laufender
    dbca zaehlt als Erstellung (erneutes `make up` waehrend des Erststarts)
  - Abbruch bei `WAS NOT SUCCESSFUL` im Container-Log (beide Images, auch gescheiterter dbca) und - nur
    bei vorhandenen Daten - bei unhealthy oder nicht healthy nach `START_TIMEOUT` 300 s (Entscheid Stefan)
  - Ausgabe: Container, letzte 20 Zeilen Alert-Log per `docker exec` (das Image tailt ihn erst nach
    seinem Start-Skript in `docker logs`), Hinweis auf `make verify` / `v$recovery_area_usage`
  - Befund Images: Healthcheck StartPeriod 300 s, 3 x 60 s - 19c ist waehrend dbca ab ca. 8 min unhealthy
- Test: Fake-docker (`COMPOSE=`) fuer alle Pfade; base26 echt: Gutfall 13 s; ORA-16038 provoziert (FRA
  unter Belegung, Archiver blockiert, `docker kill`) -> Abbruch nach 11 s mit ORA-16038/19809 im Tail;
  rebuild 134 s, reset 10 s, base26 gestoppt. seclab nicht angefasst
- `DRY_RUN` in labctl: nur `TRUE` galt, `DRY_RUN=1` direkt lief scharf - jetzt `TRUE|1|yes` /
  `FALSE|0|no`, sonst Fehler
- open-work.md: "Docker-RAM zurueck auf 8 GB" gestrichen (Entscheid: 16 GB bleiben)

## Pendenzen

<!-- markdownlint-disable MD013 MD060 -->
| # | Was | Bis | Wer | Status |
| --- | --- | --- | --- | --- |
| 1 | Host-Platte 98 % (12 GB frei), `~/oradba-labs-data/audit26` 4.6G Herkunft klaeren | - | Stefan | offen |
| 2 | base19 LABPDB1 enthaelt `HR` (19c-Template), base26 nicht - gewollt? | - | Stefan | offen |
| 3 | Lab-Images auf oradba-docker umstellen (labs-M2), Free-Version pinnen | 2026-11-27 | Session | offen, haengt am Aufbau von oradba-docker (labs-M1) |
<!-- markdownlint-restore -->

## Open (P1)

- keine

## Open (P2)

- [ ] Host-Platte 98 %: `~/oradba-labs-data` 41 GB (seclab 26G, audit26 4.6G)
- [ ] Lab-Images auf oradba-docker umstellen (labs-M2), Free-Version pinnen
- [ ] Rollen-Abschnitt in hold-my-beer, talks, oradba, ora-db-audit-eng (nach DOAG)

## To resume

```bash
cd ~/Repos/own/oehrlis/oradba-labs
du -sh ~/oradba-labs-data/*
sed -n '/### Befunde/,$p' tasks/open-work.md
```
