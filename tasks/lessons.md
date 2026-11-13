# Lessons - oradba-labs

## 2026-11-13 - Eigene Designentscheide ohne Rueckfrage (M0)

**Was passiert ist:** Fuer die Daten der Lab-Container habe ich Docker named volumes gewaehlt
statt der Bind-Mounts, die oracle-free-labs (`./data/<service>`) und docker/samples verwenden.
Ein named volume uebernimmt beim ersten Start den Inhalt des Images - beim Free-Image die
vorgebaute DB samt `.FREE.created`. `runOracle.sh` hielt die DB fuer bestehend und uebersprang
`setup/`. Statt die Abweichung zurueckzunehmen, habe ich einen Workaround gebaut (labctl fuehrt
die Setup-Hooks aus, Marker-Datei, Restore Point verwerfen) und ihn als "Befund im Image"
dokumentiert. Bei 19c habe ich das Muster aus `docker/samples` (Setup-Skript oeffnet die PDB
selbst) nicht uebernommen, sondern den Fehler im Image gesucht. Ebenfalls ohne Rueckfrage:
Reset per Guaranteed Restore Point statt des bestehenden Neuaufbaus.

**Regel:**

- Ein Konzept, keine Varianten. Erst das Muster der Vorgaenger-Repos uebernehmen
  (oracle-free-labs, docker/samples, oracle-database-docker), dann bauen
- Container-Labs: Bind-Mounts fuer die Daten, Konfiguration ueber `setup/` + `startup/`.
  19c (ora_db) erstellt die DB per dbca, Free bringt eine mit - konfiguriert werden beide
  gleich; die neuen oradba-docker-Images 19c/26ai EE ebenso
- Widerspricht ein Symptom jahrelang funktionierender Praxis, ist es meine Abweichung, kein
  Image-Fehler: zuerst gegen das Vorgaenger-Repo diffen
- Jeder Mechanismus, den der Brief nicht festlegt (Volume-Typ, Init, Reset, Tooling-Schicht),
  geht in die eine Klaerungsrunde vorab - nicht in den Code
- Keine alten RU-Images neu bauen (alte RUs nur mit Passwort herunterladbar; Images entstehen
  neu in oradba-docker)

verify: jede Abweichung von oracle-free-labs/docker-samples in `labs/*/compose.yml` ist in der
Klaerungsrunde genannt und von Stefan entschieden

## 2026-11-13 - Einzel-Commit nahm gestagte Arbeit mit

**Was passiert ist:** Fuer einen Commit nur von `docs/architecture.md` lagen im Index noch `git rm` /
`git mv` aus dem laufenden Umbau. `git add <datei> && git commit` nahm alles mit, gepusht - trotz
sichtbarem `--stat`. `main` war halb umgebaut, korrigiert mit `5b58d79` (Revert der Loeschungen).

**Regel:** Vor einem Teil-Commit `git diff --cached --name-only` lesen - steht mehr drin als gemeint,
`git commit <pfad>` (nur dieser Pfad) oder vorher aus dem Index nehmen. Ein `--stat`, das mehr zeigt
als erwartet, ist ein Stopp, kein Hinweis.

verify: `git diff --cached --name-only` vor jedem Commit = genau die gemeinten Pfade
