# Open work - oradba-labs

## v0.2.0 - Mechanik nach E8-E14 (2026-11-13)

- [x] Vertrag (E8): Oracle-Container-Muster, Hooks ueber das Image, `trivadis/ora_db` gemappt
- [x] Storage (E9): `bind` unter `LAB_DATA_BASE`; `volume` vorerst abgelehnt (M5)
- [x] Lebenszyklus (E10): Baseline per Startup-Hook, `make reset` (Flashback), `make rebuild`
- [x] seclab (E11) mit `LABPDB1` + `DEMOPDB`; base26 = labdb (E14 `LABPDB1`)
- [x] Hooks + Skripte 1:1 aus oracle-free-labs; `create_pdb.sql`-Fix zurueckportiert (`9b12381`);
  Legacy-Profile/-User aus `common_db_config.sql` entfernt (beide Repos)
- [x] Tests: seclab frisch (dbca 15 min) verify 28 OK, reset 53 s; seclab db26 Image-Wechsel
  Free -> oracle-free-labs:latest auf denselben Daten ok; base26 frisch 143 s, reset 11 s;
  deep-data-Demos auf base26 alle rc=0
- [x] Demos verifier / unified-audit / tde live pruefen, Tag `v0.2.0` (`9b04ab7`, Tag auf origin)

## So 2026-11-22 - Test-Session (Labs + Demos)

- [x] `make up LAB=seclab` / `make up LAB=base26`, `make verify`, `make reset` - je einmal [P1]
  - seclab: up blieb haengen, db19 stoppte mit ORA-19809/16038 (FRA 6400M voll, Archivelogs aller
    Reset-Incarnations); per RMAN die Logs ausserhalb Incarnation 2 (`LAB_BASELINE`) geloescht ->
    up rc=0, verify 28 OK, reset 61 s / 48 s. base26: up 11 s, verify 8 OK, reset 17 s
- [x] `make rebuild LAB=base26` - 125 s, verify 8 OK, LABPDB1 nur `PDBADMIN`, keine Legacy-Profile [P1]
- [x] Demos verifier (db19), unified-audit (db19, db26), tde (db26) je einmal komplett [P1]
  - alle rc=0, Zeiten in den Demo-READMEs; `reset.sql` hinterlaesst jeweils die Baseline
- [x] TDE: nach `tde` + `make reset LAB=seclab` bleibt `masterkey_activated` = YES auf db26
  (CDB$ROOT, LABPDB1, DEMOPDB) - Flashback setzt es nicht zurueck; README + `reset.sql` korrigiert [P1]
- [x] `base19` einzeln end-to-end: frischer dbca 14.5 min, verify 9 OK, reset 47 s (rebuild ausgelassen) [P2]

### Befunde / neu

- [x] FRA-Wachstum durch `make reset`: Entscheid Stefan 2026-11-23 - `labctl reset` loescht per RMAN die
  Archivelogs verwaister Incarnations (Baseline- und aktuelle Incarnation bleiben); zwei Resets in Folge ok,
  `make verify` warnt ab 80 % [P1]
- [ ] Host-Platte 98 % (12 GB frei): `~/oradba-labs-data` 41 GB (seclab 26G, audit26 4.6G - kein Lab
  hier, Herkunft klaeren) [P2]
- [ ] base19 LABPDB1 enthaelt `HR` (19c-Template), base26 nicht - gewollt? [P3]
- [ ] `labctl wait` meldet bei bestehenden Daten "first start creates the databases" und wartet ohne
  Hinweis auf eine gescheiterte Instanz (unhealthy 10 min) - Abbruch mit Alert-Log-Tail [P2]

## Next

- [ ] Rollen-Abschnitt in hold-my-beer, talks, oradba, ora-db-audit-eng (nach DOAG) [P2]
- [ ] E12 (b) DB-VM mit oci-labs + oradba-ansible [P2]
- [ ] `volume` + Podman (M5), Docker-RAM im Alltag zurueck auf 8 GB [P3]
- [ ] M2: Images aus oradba-docker, Free-Version pinnen [P2]
