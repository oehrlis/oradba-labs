# Open work - oradba-labs

## M0 (2026-11-13) - v0.1.0

- [x] `make list` shows base19, base26, seclab
- [x] `make up LAB=seclab` -> both DBs healthy, connect strings printed
- [x] `make reset LAB=seclab` < 5 min (measured 43-80 s)
- [x] `make down LAB=seclab` keeps volumes, `PURGE=1` removes them
- [x] public, `v0.1.0` pushed, gitleaks clean
- Abweichung: eigene Mechanik (named volumes, Setup-Schicht in labctl) - Korrektur v0.2.0,
  siehe `tasks/lessons.md` und `~/notes/prompts/lab-architecture.md` E8-E11

## v0.2.0 - Mechanik nach E8-E11 (Plan, wartet auf Freigabe)

Vorlage: oracle-free-labs (Mechanik), oracle/docker-images SingleInstance (Vertrag).

- [ ] **Vertrag (E8)**: Free-Services wie oracle-free-labs - `/opt/oracle/oradata`,
  `/opt/oracle/scripts/setup` + `/startup`, `common` read-only unter `/opt/oracle/common`,
  Healthcheck des Images (kein eigener). `trivadis/ora_db` gemappt wie docker/samples:
  Daten `/u01`, `INSTANCE_INIT=/u01/config`, `setup/` + `startup/` nach `/u01/config/`
- [ ] **Storage (E9)**: `LAB_DATA_BASE` (Default `~/oradba-labs-data`) und `LAB_STORAGE=bind|volume`
  in `lab.env`; `volume` mit `nocopy`. Vorschlag Umsetzung: je Storage-Typ eine kleine
  Override-Datei in `common/compose/`, die das Skript dazulegt - **Freigabe noetig**
- [ ] `COMPOSE=docker|podman` (Default docker); Podman ist lokal nicht installiert -> Test offen
- [ ] **Setup ueber das Image**: `labctl`-Provisioning, Marker `.oradba-labs.setup` und
  `/tmp/oradba-labs.ready`, eigener Healthcheck, compose-Labels `oradba.labs.*` entfernen.
  Setup-SQL oeffnet die PDB selbst (Muster docker/samples). `lab_sql.sh` -> `run_sql_script.sh`
  und `define_logging_*` aus oracle-free-labs
- [ ] **Lebenszyklus (E10)**: Baseline per Startup-Hook (`LAB_BASELINE` anlegen, falls fehlt -
  laeuft nach Setup); `make up` wartet auf healthy + Baseline vorhanden. `make reset` = Flashback
  (bleibt), neu `make rebuild` = down, Daten loeschen (bind: Verzeichnis, volume: `down -v`), up.
  Vorlage restaurieren (RMAN/Seed) = Image-Feature, M2 in oradba-docker - in v0.2.0 nur benannt
- [ ] **seclab (E11)**: sauber wie jetzt; `PROFILE=insecure` nur als Platzhalter im README (M3)
- [ ] Verify ohne Labels: Services aus `compose ps`, PDBs aus `v$pdbs`, Ports aus `lab.env`
- [ ] Doku: README, CLAUDE.md, common/README, Lab-READMEs, CHANGELOG `0.2.0` (Changed/Removed mit
  Begruendung); falsche Aussage "Free ueberspringt setup/" entfernen
- [ ] Tests: seclab frisch mit bind (labdb vorher stoppen, ~16 min dbca), reset, down;
  base26 mit volume: up, reset, rebuild, down PURGE; Lint, gitleaks; Tag `v0.2.0` pushen

## Next

- [ ] talks-privesc: `make up LAB=seclab`, Modul 4 darauf (nach v0.2.0) [P1]
- [ ] M0b (2026-11-16): hold-my-beer und deep-data -> Lab (`seclab` / `base26`) [P2]
- [ ] Podman testen (Mac und Cloud-Instanz) [P2]
- [ ] M2: Images in `lab.env.example` auf `oradba-docker`, Vorlage-Restore, Free-Version pinnen [P2]
- [ ] E12 (OCI-Modell) klaeren vor M5 [P3]
