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
- [-] Demos verifier / unified-audit / tde live pruefen (Agent laeuft), dann Tag `v0.2.0`

## Sa 2026-11-14 - Test-Session Stefan (Labs + Demos)

- [ ] `make up LAB=seclab` / `make up LAB=base26`, `make verify`, `make reset` - je einmal [P1] (due: 2026-11-14)
- [ ] `make rebuild LAB=base26` (frisch, prueft das Setup ohne Legacy-Objekte, ~3 min) [P1] (due: 2026-11-14)
- [ ] Demos `demos/verifier`, `demos/unified-audit`, `demos/tde` einmal pro Rolle durchspielen [P1] (due: 2026-11-14)

## Mo 2026-11-16 abend (M0b) - DOAG Di 2026-11-17

- [ ] deep-data (08:30): Probe auf base26 mit eigenem `DDS_PWD`, SQLcl-Verbindungen Port 1571;
  Entscheid base26 oder labdb (Fallback laeuft, Port 1527) [P1] (due: 2026-11-16)
- [ ] hold-my-beer (15:00): Aufgaben verifier, unified-audit, tde auf seclab proben, Zeiten
  pruefen (TDE mit zwei Restarts) [P1] (due: 2026-11-16)
- [ ] privesc: `make up LAB=seclab`, Modul 4 auf seclab-db19 (19.27); State in talks-privesc
  nachfuehren (19.31 -> 19.27) [P1] (due: 2026-11-16)

## Next

- [ ] `base19` einzeln end-to-end (Hooks liefen in seclab-db19) [P2]
- [ ] Rollen-Abschnitt in hold-my-beer, talks, oradba, ora-db-audit-eng (nach DOAG) [P2]
- [ ] E12 (b) DB-VM mit oci-labs + oradba-ansible (Di/Mi 17./18.11.) [P2]
- [ ] `volume` + Podman (M5), Docker-RAM im Alltag zurueck auf 8 GB [P3]
- [ ] M2: Images aus oradba-docker, Free-Version pinnen [P2]
