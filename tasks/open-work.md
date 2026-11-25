# Open work - oradba-labs

Nur offene Tasks. Erledigtes steht im CHANGELOG, in `docs/architecture.md` und in der git-History.

## Jetzt

- [ ] 26ai-Labs auf Free 23.26.4 - Entscheid offen (Stefan) [P1]
  - `container-registry.oracle.com/database/free:23.26.4.0` (= `latest`) bringt kein dbca-Template mehr
    (`FREE_Database.dbc` fehlt, 23.26.3.0 hat es), nur `prebuilt-oradata.tar.gz`. `startPrebuilt.sh` entpackt es
    in das leere Bind-Verzeichnis, `setup/` laeuft nie; `runOracle.sh` direkt (compose `command:`) scheitert mit
    DBT-10508. Getestet 2026-11-23 auf leerem seclab-db26, zurueckgenommen. Kein anderer 23.26.4-Tag ausser `-lite`
  - Die Registry-Doku beschreibt das Gegenteil: "An empty host directory hides the prebuilt database at
    /opt/oracle/oradata and starts a new database setup" und "Setup scripts ... run when an empty data directory
    causes a new database setup". Keine Release Notes, im Image fehlen README.md und Dockerfile - vermutlich
    fehlerhafter Build. Rueckfrage bei Oracle: Tasks im PKM (Chris Saxon UKOUG, Mail Gerald Venzl / Martin Bach)
  - Optionen: Setup-Schritte als idempotente Startup-Hooks auf der Prebuilt-DB (Umbau der Lab-Mechanik,
    Architektur-Entscheid 8) - oder bei 23.26.3 bleiben, bis oradba-docker ein eigenes Image baut (labs-M2)
  - Danach umstellen: base26, audit26 (nach dem Purge-Test), seclab beim Neuaufbau; 19c bleibt `trivadis/ora_db`
  - Stand 2026-11-25 (Belege `docs/evidence/free-23-26-4/`, Gate erledigt): kein fehlerhafter Build, sondern ein
    gewollter Umbau mit unvollstaendiger Doku. `startPrebuilt.sh` und `configurePrebuiltPdb.sh` sind neu ("Since:
    September, 2026"), die Prebuilt-DB liegt als tar.gz im Image. `ORACLE_CHARACTERSET` konvertiert nur noch
    `FREEPDB1` per `INTERNAL_CONVERT`, `CDB$ROOT` bleibt AL32UTF8. Ein fehlerhaftes Startup-Skript beendet den
    Container. Der Create-Pfad hat kein Template mehr, bei SID != FREE fehlt auch das Response-Template.
    Registry-Doku und GitHub (oracle/docker-images) beschreiben noch 23.26.3. Groessendifferenz: dnf-Cache 0.67
    GB und Seed-Dateien 0.39 GB komprimiert - die Vermutung "1.6 GB = Seed" ist widerlegt
  - Fuer den Entscheid: Startup-Hooks auf der Prebuilt-DB muessen idempotent sein **und** fehlerfrei enden (sonst
    stoppt der Container). Ein anderer Zeichensatz (z.B. dict-Labs) geht nur auf PDB-Ebene, die CDB bleibt AL32UTF8
- [ ] Laufzeit-Tests Free 23.26.4 offline starten (Flieger, Stefan): `caffeinate -dims
  docs/evidence/free-23-26-4/collect.sh --phase runtime --yes`, Strom + Deckel offen, ca. 1-2 h [P1]
- [ ] Free 23.26.4: `raw/` auswerten, Tabelle belegt/widerlegt/offen in `docs/evidence/free-23-26-4/README.md`
  nachfuehren, `mail-draft.md` schreiben (oder Empfehlung "keine Mail"/Doku-Rueckmeldung), dann Entscheid oben
  [P1]

## Wartet

- [ ] base26 neu erstellen (`make rebuild LAB=base26`) und in `labs/base26/verify.sh` `LABPDB1:SCOTT,TVD_HR`
  erwarten - base26 belegt bis Di 2026-11-24 10:00 (MFA-Demo UKOUG), vorher meldet verify FAIL [P2] (due: 2026-11-25)
- [ ] audit26: Image erst nach dem Purge-Test von ora-db-audit-eng umstellen, auf dessen Zeichen (lab.env +
  rebuild; danach wiederholt ora-db-audit-eng `sql/tst_dmlddl_aud.sh`) [P2] (due: 2026-11-27)
- [ ] seclab neu erstellen (`make up LAB=seclab`, 19c-dbca ca. 15 min) - am 2026-11-23 samt Daten geloescht
  (Entscheid Stefan); damit sind auch die Weak-States der privesc-Demo weg [P2]

## audit26 - Rest der Migration aus ora-db-audit-eng (labs-M3)

- [ ] App-Simulator (classic/paas/k8s aus `ora-db-audit-eng/lab/app`) als Service in `labs/audit26` [P2] (due: 2026-12-04)
- [ ] Alte Setup-Schritte 20-35 einordnen: Rollen, DBA-/Audit-User, ODBDBA-Kontext - Lab (`common/`) oder
  Demo beim Konsumenten; Policy-SQL bleibt in `ora-db-audit-eng/sql/` [P2] (due: 2026-12-04)
- [ ] `ora-db-audit-eng/lab` abloesen (Makefile `lab-*` auf `make ... LAB=audit26`, `lab/` per `git rm`,
  CHANGELOG `Removed`), Migrationstabelle in `~/notes/prompts/lab-architecture.md` nachfuehren [P2] (due: 2026-12-04)

## Milestones

- [ ] Image-Repo oradba-docker anlegen (labs-M1) - gibt es noch nicht; Task in `~/notes/areas/oci-labs.md` [P1]
- [ ] Lab-Images auf oradba-docker umstellen, Free-Version pinnen (labs-M2) [P2]
  - Entscheid Stefan 2026-11-23: bis dahin bleiben `trivadis/ora_db` und `oracle-free-labs`; die alten aehnlichen
    Image-Repos werden spaeter abgeloest oder ueberfuehrt
- [ ] Docker named volumes + Podman (labs-M5) [P3]

## Backlog

- [ ] Rollen-Abschnitt in hold-my-beer, talks, oradba, ora-db-audit-eng (nach DOAG) [P2]
- [ ] Datenbank-VM auf OCI mit oci-labs + oradba-ansible (Architektur-Entscheid 12, Variante b) [P2]
- [ ] Host-Platte: 92 % / 37 GB frei nach dem Loeschen von seclab; `~/oradba-labs-data/audit26` bleibt bis zum
  Purge-Test (2026-11-27) [P3]
- [ ] Archiver-Stillstand im Betrieb bleibt healthy: der Healthcheck liest nur `v$database.open_mode`, eine
  suspendierte Instanz meldet READ WRITE - nur `make verify` (FRA-WARN) zeigt es [P3]
