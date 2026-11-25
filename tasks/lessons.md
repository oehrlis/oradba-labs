# Lessons - oradba-labs

Die allgemeine Lab-Regel (Bind-Mount, nur `setup/` + `startup/`, Mechanismen vorab fragen, gegen
oracle-free-labs diffen) steht in der globalen Rule `labs.md`. Hier nur, was dieses Repo betrifft.

## 2026-11-13 - Eigene Designentscheide ohne Rueckfrage (labs-M0)

**Was passiert ist:** Named volumes statt Bind-Mounts. Das Volume uebernahm die vorgebaute Free-DB samt
`.FREE.created`, `runOracle.sh` uebersprang `setup/`. Statt zurueckzunehmen, baute ich einen Workaround
(labctl fuehrt die Hooks aus, Marker-Datei) und nannte es "Befund im Image". Ebenfalls ohne Rueckfrage: Reset
per Guaranteed Restore Point. v0.2.0 musste beides zurueckbauen.

**Regel (repo-spezifisch):**

- 19c (`trivadis/ora_db`) erstellt die DB per dbca, Free per `createDB.sh` auf leerem Bind-Verzeichnis -
  konfiguriert werden beide gleich ueber `setup/` + `startup/`. Bei 19c das Muster aus `docker/samples`
  uebernehmen (Setup-Skript oeffnet die PDB selbst)
- Keine alten RU-Images neu bauen (alte RUs nur mit Passwort herunterladbar); neue Images entstehen in
  oradba-docker

verify: jede Abweichung von oracle-free-labs / docker-samples in `labs/*/compose.yml` ist von Stefan entschieden

## 2026-11-13 - Einzel-Commit nahm gestagte Arbeit mit

**Was passiert ist:** Im Index lagen noch `git rm` / `git mv` aus dem Umbau; `git add <datei> && git commit`
nahm alles mit und pushte es. Korrigiert mit `5b58d79`.

**Regel:** Vor einem Teil-Commit `git diff --cached --name-only` lesen. Steht mehr drin als gemeint:
`git commit <pfad>` oder vorher aus dem Index nehmen.

verify: `git diff --cached --name-only` vor jedem Commit = genau die gemeinten Pfade

## 2026-11-23 - `make up` auf einem fremden Lab erzeugte eine neue lab.env

**Was passiert ist:** `make up LAB=audit26` im Haupt-Checkout; die `lab.env` lag nur im Worktree der
ora-db-audit-eng-Session. `ensure_env` legte eine neue aus der gerade umgestellten Vorlage an (23.26.4 auf
23.26.3-Daten, neue Passwoerter); die INFO-Zeile dazu hatte ich per `tail` abgeschnitten. Kein Schaden
(Dictionary geprueft), lab.env aus dem Worktree kopiert.

**Regel:** Vor `make up` auf einem Lab einer anderen Session `ls labs/<lab>/lab.env` im eigenen Checkout. Fehlt
sie: beim Besitzer nachfragen, nie die Vorlage erzeugen lassen. `make up`-Ausgaben nicht abschneiden.

verify: vor jedem `make up` eines fremden Labs existiert `labs/<lab>/lab.env` im aktuellen Checkout

## 2026-11-25 - Pruef-Gate per Pipe verschluckt, Commit trotz rotem `make check`

**Was passiert ist:** `make check 2>&1 | tail -4 && git commit ...` - gitleaks meldete einen Fund, `make` endete
mit Fehler, die Pipe lieferte aber den Exit-Code von `tail` (0), der Commit lief durch. Kurz danach nochmals mit
`markdownlint ...; git commit` (Semikolon statt `&&`). Der Fund war harmlos (oeffentlicher Analytics-Key im
gitignorierten `.work/`), beide Commits waren ungepusht und wurden per `--amend` korrigiert.

**Regel:** Ein Gate vor `commit`/`tag`/`push` nie durch eine Pipe oder mit `;` verketten. Gate allein ausfuehren
(Ausgabe in eine Datei, `rc=$?` pruefen) oder `set -o pipefail` setzen - erst bei rc=0 committen.

verify: kein `make check ... | ... && git commit` und kein `<lint>; git commit` im Session-Verlauf; vor jedem
Commit steht ein `make check` mit rc=0
