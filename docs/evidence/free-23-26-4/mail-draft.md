# Mail draft - Free 23.26.4.0 container image

Status: draft, not sent. Every statement below is backed by a file in this folder (see `README.md`).

Subject: Oracle AI Database Free 23.26.4.0 container image - registry docs describe 23.26.3 behaviour

---

Hi Gerald, hi Martin,

I asked Chris Saxon about this at UKOUG; he was not aware of the change either, so I am reaching out to you
directly.

Since `container-registry.oracle.com/database/free:23.26.4.0` (= `latest`, digest
`sha256:f5a1791bf5628fd1a97e07584ff5ac5537da5021c23e70f5083f48c8fcd6476e`) the Full image handles an empty data
directory differently from 23.26.3.0. The new `startPrebuilt.sh` and `configurePrebuiltPdb.sh` look like an
intended redesign, but the registry page still describes the old behaviour, and the old create path is left
without its inputs. I compared both images on arm64 (commands and raw output:
<https://github.com/oehrlis/oradba-labs/tree/main/docs/evidence/free-23-26-4>).

What I see on 23.26.4.0:

1. An empty mounted host directory gets the extracted prebuilt database. `/opt/oracle/scripts/setup` never runs;
   startup scripts do. The registry page says: "An empty host directory hides the prebuilt database at
   /opt/oracle/oradata and starts a new database setup" and "Setup scripts ... run when an empty data directory
   causes a new database setup".
2. `ORACLE_CHARACTERSET` now converts only `FREEPDB1` (`INTERNAL_CONVERT`); `CDB$ROOT` stays `AL32UTF8`. The page
   says the variable "has no effect when /opt/oracle/oradata already contains a database" and recommends a new
   empty directory for another character set.
3. A failing startup script now stops the container (exit code 1, no message saying why). In 23.26.3.0 the error
   was logged and the database kept running. The page does not mention this.
4. The create path cannot work any more:
   - `FREE_Database.dbc` and the seed files are gone from `$ORACLE_HOME/assistants/dbca/templates`, but
     `createDB.sh` / `oracle-free-26ai configure` still use them. Starting `runOracle.sh` directly on an empty
     directory fails with `[DBT-10508] Invalid template file specified`.
   - With `ORACLE_SID` other than `FREE`, the container exits before DBCA: `RELINK_BINARY_FILE` and `CONFIG_RSP`
     are not set in the image.
5. `/opt/oracle/README.md` and `Dockerfile` are no longer in the image, and I found no release notes for 23.26.4.0.

Minimal reproduction (empty directories, arm64):

```bash
docker run -d --name free-a -e ORACLE_PWD=<pwd> -v $PWD/a/oradata:/opt/oracle/oradata -v $PWD/a/setup:/opt/oracle/scripts/setup:ro container-registry.oracle.com/database/free:23.26.4.0
docker run -d --name free-b -e ORACLE_PWD=<pwd> -e ORACLE_SID=LABSID -v $PWD/b/oradata:/opt/oracle/oradata container-registry.oracle.com/database/free:23.26.4.0
```

`free-a` (`a/setup/01_marker.sh` echoes a marker): ready after 31 s, the log shows
`Expanding prebuilt database files.` and `DATABASE IS READY TO USE!`, the setup marker never appears. The same run
on 23.26.3.0 creates a new database with DBCA (112 s) and runs the setup script.

`free-b` exits with code 1 after 21 s:

```text
Expanding prebuilt database files.
/opt/oracle/scripts/base/runOracle.sh.orig: line 435: source: /opt/oracle/: is a directory
Response file template  not found in /opt/oracle or /opt/oracle/scripts/base.
```

Questions:

- Is the prebuilt-only behaviour the intended design from 23.26.4 on? If so, could the registry page be updated
  (empty directory, setup scripts, `ORACLE_CHARACTERSET`, failing startup scripts)?
- Is there still a supported way to create a fresh database in the Full image (own SID, CDB character set, setup
  scripts), or should the create path in `runOracle.sh` / `createDB.sh` be removed?

Thanks and best regards,
Stefan
