# Open work - oradba-labs

## M0 (2026-11-13)

- [x] `make list` shows base19, base26, seclab
- [x] `make up LAB=seclab` -> both DBs healthy, connect strings printed (first start ~16 min, then ~25 s)
- [x] `make reset LAB=seclab` < 5 min (measured 43-80 s, both DBs in parallel)
- [x] `make down LAB=seclab` keeps volumes, `PURGE=1` removes them (PURGE tested on base26)
- [x] public, `v0.1.0` pushed, gitleaks clean

## Next

- [ ] M0b (2026-11-16): hold-my-beer and deep-data demos -> lab (`seclab` / `base26`) [P2]
- [ ] Test `base19` standalone end to end (only its hooks were tested, inside `seclab`) [P2]
- [ ] M2: switch `lab.env.example` images to `oradba-docker`, pin the Free version [P2]
- [ ] Memory: `seclab` (~6 GB) and `labdb` (oracle-free-labs, 3 GB) do not fit the 7.75 GB
  Docker VM together - stop labdb or raise the VM memory [P3]
