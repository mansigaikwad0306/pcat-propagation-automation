# PCAT Post-Propagation Automation Platform

[![CI](https://github.com/mansigaikwad0306/pcat-propagation-automation/actions/workflows/ci.yml/badge.svg)](https://github.com/YOUR-USERNAME/pcat-propagation-automation/actions)

Automated post-propagation validation for telecom billing (Amdocs Comverse PCAT) — covering **21 production servers** (TSP, SAPI, OMSAPI) in one run.

## Problem

After PCAT propagation in PROD, operators manually:
- Checked DB propagation status
- Reloaded SAPI cache on 4 servers (browser/GUI)
- SSH'd to 13 TSP/SLU servers for version checks
- Checked SAPI/OMSAPI reseller versions one by one

**Time:** ~45–50 minutes per propagation  
**Risk:** Missing a server, human error, inconsistent notes

## Solution

Single Bash script (+ Docker + CI/CD) that:
1. Confirms propagation SUCCESS in DB
2. Reloads SAPI cache on all 4 SAPI nodes
3. Prints version tables for TSP (13) + SAPI (4) + OMSAPI (4)
4. Optional team email

**Time:** ~8–10 minutes  
**Reduction:** ~80% manual effort

## Architecture

```
Jump Box (Linux)
      │
      ├── Step 1: DB check (manual confirm + SQL)
      │
      ├── Step 2: curl → SAPI cache reload (x4)
      │         10.140.33.140–143
      │
      └── Step 3: Version report
                ├── TSP  → SSH to 13 SLU/DSLU/NOTIF
                ├── SAPI → getResellerInfo.jsp (x4)
                └── OMSAPI → getResellerInfo.jsp (x4)
```

## Tech Stack

| Category | Tools |
|----------|-------|
| Scripting | Bash, Linux |
| Containers | Docker |
| CI/CD | GitHub Actions |
| Version Control | Git, GitHub |
| Protocols | SSH, HTTP/curl |

## Project Structure

```
pcat-propagation-automation/
├── scripts/
│   └── propagation_post_prod.sh    # Main automation script
├── docs/
│   └── runbook.md                  # Operator guide
├── config/
│   └── env.example                 # Environment variables template
├── .github/workflows/
│   └── ci.yml                        # CI pipeline
├── Dockerfile
└── README.md
```

## How to Run

### On jump box (production)

```bash
export SSH_PASS='your-ssh-password'
export TEAM_EMAIL='team@company.com'
bash scripts/propagation_post_prod.sh 5891
```

Replace `5891` with your propagation **work_id**.

Version check only:
```bash
bash scripts/propagation_post_prod.sh --versions-only
```

### With Docker

```bash
docker build -t pcat-propagation-automation .
docker run --rm pcat-propagation-automation --versions-only
```

## Servers Covered

| Type | Count | IPs |
|------|-------|-----|
| SAPI | 4 | 10.140.33.140–143 |
| OMSAPI | 4 | 10.140.33.144, .145, .192, .193 |
| TSP/SLU | 13 | gy-slu1–8, gy-dslu1–3, gy-notif1–2 |

## CI/CD Pipeline

On every push to `main`:
- Bash syntax check
- Docker image build
- Container smoke test

## Security Note

**Never commit passwords.** Use environment variables (`SSH_PASS`, `TEAM_EMAIL`). See `config/env.example`.

## Results

| Metric | Before | After |
|--------|--------|-------|
| Time per check | ~45 min | ~8 min |
| Servers checked | Manual, easy to miss | All 21 automated |
| Output format | Ad-hoc notes | Standard tables |
| Repeatability | Low | High (script + Docker) |

## Author

**Mansi Gaikwad**  
