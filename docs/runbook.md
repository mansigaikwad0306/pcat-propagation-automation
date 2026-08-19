# Operator Runbook

## When to run
After PCAT propagation shows **status_id = 80** in `dp_work`.

## Where to run
Jump box: `10.141.0.83` or `10.26.7.106` (on VPN)

## Commands

```bash
export SSH_PASS='your-password'
bash scripts/propagation_post_prod.sh <WORK_ID>
```

Version check only:
```bash
bash scripts/propagation_post_prod.sh --versions-only
```

## Verify
- All SAPI show same Res Ver
- All OMSAPI show same Res Ver
- TSP versions consistent

## After script
- Email NOC
- Email client
- Update OTRS/JIRA
