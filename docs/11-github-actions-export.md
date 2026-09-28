# Export on GitHub Actions (no local access needed)

The export has to run somewhere that can reach Azure SQL on port 1433. Neither
this development sandbox nor your laptop has to: the workflow
[`.github/workflows/export-livebit.yml`](../.github/workflows/export-livebit.yml)
runs the export on a GitHub-hosted runner. It then **proves the generated SQL
loads into a real PostgreSQL 16** and commits the result to the repo.

```
 GitHub runner (ubuntu-latest)
 ┌──────────────────────────────────────────────────────────────────────────┐
 │ check secrets → (optional) open SQL firewall for runner IP → connect test │
 │ → dbmigrate export → close firewall → dbmigrate load-dump into Postgres16 │
 │ → job summary → artifact (14 days) → commit export/<db>/ → push          │
 └──────────────────────────────────────────────────────────────────────────┘
          ▲ 1433                                        │ git push
  coe-index-db-server.database.windows.net       export/livebit/ in this repo
```

The first run takes about 5 minutes of setup: two secrets and one firewall
choice.

## 1. Add the two required secrets

In GitHub, open the repository **aicloudomax/dbmigration**, then:

1. **Settings** (top bar of the repo) → **Secrets and variables** (left sidebar)
   → **Actions**.
2. Stay on the **Secrets** tab (not *Variables*) and click
   **New repository secret**.
3. Name `SRC_MSSQL_USER`, value = the SQL login name. Click **Add secret**.
4. Again **New repository secret**: name `SRC_MSSQL_PASSWORD`, value = that
   login's password. Click **Add secret**.

Direct link: `https://github.com/aicloudomax/dbmigration/settings/secrets/actions`.

Use **repository** secrets, not *environment* secrets: the workflow does not use a
GitHub environment, so it cannot see environment secrets.

If either secret is missing, the run stops at its first step with:
`Missing repository secrets: Required secret(s) not set: ...`.

Use a read-only login. It needs to read the tables and the definitions of views
and routines:

```sql
-- in the LiveBit database
ALTER ROLE db_datareader ADD MEMBER [<login_user>];
GRANT VIEW DEFINITION TO [<login_user>];
```

## 2. Let the runner reach the SQL server (pick one)

A GitHub runner gets a new public IP on every run, so a fixed firewall rule
cannot work. Pick **A** or **B**.

### A. Allow Azure services (simplest)

GitHub-hosted Linux runners run inside Azure, so this switch lets them in:

1. Azure portal → **SQL servers** → `coe-index-db-server`.
2. **Security → Networking** → **Public access** tab.
3. Under **Exceptions**, tick **Allow Azure services and resources to access
   this server** → **Save**.

This admits connections from any Azure-hosted address, and they still need the
SQL login. You can switch it off again after the export.

### B. Temporary firewall rule per run (optional `AZURE_*` secrets)

Add four more repository secrets (same place as step 1). The workflow then logs
in to Azure and adds a rule `gh-runner-<run id>` for the runner's IP only. It
**removes the rule right after the export**, even if the export fails or the
run is cancelled.

| Secret | Value |
| --- | --- |
| `AZURE_CLIENT_ID` | Service principal application (client) ID |
| `AZURE_CLIENT_SECRET` | Service principal client secret |
| `AZURE_TENANT_ID` | Microsoft Entra tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Subscription that holds `coe-index-db-server` |

To create a service principal that is allowed to do only this, run the
following from an Azure Cloud Shell. Replace the placeholders with your
subscription ID and the server's resource group:

```bash
az ad sp create-for-rbac --name gh-dbmigration-export \
  --role "SQL Server Contributor" \
  --scopes /subscriptions/<SUBSCRIPTION_ID>/resourceGroups/<RESOURCE_GROUP>
```

Its output maps to the secrets like this: `appId` → `AZURE_CLIENT_ID`,
`password` → `AZURE_CLIENT_SECRET`, `tenant` → `AZURE_TENANT_ID`.

The workflow finds the server's resource group with `az sql server list`. If the
run log warns that the server *was not found*, also give the principal
**Reader** on the subscription.

The `AZURE_*` secrets are optional. If `AZURE_CLIENT_ID` is empty, the Azure
steps are skipped. If the login or rule creation fails (for example, missing
rights), the run shows a yellow **warning** and continues. The connection then
works only if option A is on.

## 3. Run it

### From the Actions tab

1. Repo → **Actions** → **Export LiveBit (MS SQL -> Postgres SQL files)** (left
   list).
2. **Run workflow** (right side) → branch `claude/change-repo-private-j9dgrc`.
3. Review the inputs and click the green **Run workflow**.

| Input | Default | Meaning |
| --- | --- | --- |
| `database` | `LiveBit` | Source database on the server |
| `server_host` | `coe-index-db-server.database.windows.net` | Source SQL server |
| `schema_only` | off | Export tables/views/routines definitions only, no row data |
| `commit_results` | on | Commit `export/<db>/` back to the branch |
| `max_commit_mb` | `1800` | Above this export size, `data/` is **not** committed (see below) |

Or from a terminal with the GitHub CLI:

```bash
gh workflow run export-livebit.yml --ref claude/change-repo-private-j9dgrc \
  -f database=LiveBit -f schema_only=false -f commit_results=true
gh run watch
```

### By committing a request file

Pushing a JSON file under `migration-requests/` also starts the workflow. Use the
same keys as the inputs; any key you leave out takes the default above:

```json
{
  "database": "LiveBit",
  "server_host": "coe-index-db-server.database.windows.net",
  "schema_only": false,
  "commit_results": true,
  "max_commit_mb": "1800"
}
```

Name it with a sortable date, e.g. `migration-requests/2026-09-28-livebit.json`.
If one push changes several request files, the newest commit's file is used. If
several files changed in the same commit, the alphabetically last one wins.
Never put credentials in a request file. The workflow's own commits do not
start it again.

## 4. What gets committed, and where

On the branch the run started from (commit author `github-actions[bot]`, message
`Export LiveBit: schema, data, views, routines (run <run id>)`):

```
export/livebit/
  manifest.json             what was exported: counts, per-table detail, review items
  01_schema.sql             CREATE SCHEMA livebit_dbo, livebit_aidd, ... + tables + indexes
  02_views.sql              views
  03_routines.sql           procedures/functions converted to PL/pgSQL
  04_foreign_keys.sql       foreign keys (applied after data)
  data/*.sql                INSERT statements per table, split into files of ~45 MB max
  validation_report.json    result of loading all of the above into Postgres 16
  DATA_NOT_COMMITTED.md     only when data/ was left out (see below)
```

- **Each run replaces `export/<db>/` completely.** Tables that no longer exist
  and old data files are removed. A `schema_only` run therefore removes
  previously committed data files. They stay in git history.
- **Size limits.** If `export/<db>/` is larger than `max_commit_mb`, everything
  **except `data/`** is committed, together with `DATA_NOT_COMMITTED.md`. That
  file lists the sizes and names the artifact holding the full export. The same
  happens if any single data file is over 95 MB, because GitHub rejects files
  over 100 MB. A single push must stay under 2 GB, so do not raise
  `max_commit_mb` above ~1900.
- **If nothing changed**, no commit is made.
- **Artifact.** The full export directory, `data/` included, is always uploaded
  as the artifact `export-livebit-run<run id>-<attempt>` and kept **14 days**.
  To download it, open the run page, scroll to **Artifacts** and click the name,
  or run `gh run download <run id>`.
- `config/migration.yaml` is created on the runner from
  `config/migration.example.yaml` and is never committed.
- **Production data ends up in git.** Anyone with read access to this private
  repo can read it, and it stays in history. If that is not acceptable, run with
  `schema_only` on, or with `commit_results` off and use the artifact.

## 5. Reading the results

### The job summary

Open the run and click **Summary**. It contains:

- **Step results**: SQL Server connectivity, Export, Validation load into
  Postgres 16.
- **Exported**: number of tables, views, routines, rows, target schemas, and
  review items.
- **Tables per schema**: one row per target schema (`livebit_dbo`,
  `livebit_aidd`, `livebit_diva`, `livebit_divaconfig`, `livebit_divadim`,
  `livebit_sandbox`, `livebit_zora`) with table/column counts and approximate
  source row counts.
- **Review items**: things the converter could not translate safely. They are
  listed in `manifest.json` → `review_items` and marked `-- REVIEW:` in the SQL.
- **Validation**: PASSED/FAILED, every failure (file/step and the Postgres
  error), and any row-count mismatches.
- **Size and commit**: export size, whether `data/` was committed, and the
  pushed commit.

### validation_report.json

`dbmigrate load-dump` writes this file after loading the export into the
throwaway `postgres:16` service on the runner. That run applies the same files
and order that a load into Supabase uses. `ok: true` means every file loaded
without error. Otherwise `failures` lists each failing file or step with the
Postgres error message.

### Green, red, and yellow

| What you see | Meaning / what to do |
| --- | --- |
| Green run | Exported, loaded cleanly into Postgres 16, committed |
| Red at **Check required secrets** | Add `SRC_MSSQL_USER` / `SRC_MSSQL_PASSWORD` (section 1) |
| Red at **Check SQL Server connectivity** | The error shows the runner IP. Enable option A or add the `AZURE_*` secrets (section 2). *SQL login failed* means wrong user/password. *Database not found* means a wrong `database` input |
| Red at **Export** | Read the step log. Nothing is committed; a partial export is in the artifact |
| *No space left on device* | The workflow frees ~20 GB of preinstalled tools first. A database whose export plus its Postgres copy exceeds the runner disk needs `schema_only`, or a larger runner |
| Run cancelled after 6 hours | GitHub's limit for hosted runners. The export is too large for one run |
| Red at **Fail the run if validation failed** | The export **was committed**, but something did not load into Postgres. Read the failures in the summary or `validation_report.json`, fix, and re-run |
| Red at **Commit and push export** | Push rejected, e.g. by branch protection that blocks `github-actions[bot]`, or a file too large. The artifact still has everything |
| Yellow warning about the firewall | The Azure login or rule creation failed. The run continued without a rule |
| Yellow warning *Could not remove firewall rule* | Delete `gh-runner-<run id>` by hand: Azure portal → SQL server → Networking → Firewall rules |

## 6. Security notes

- Secrets are mapped into the job once and are never printed. Shell tracing is
  never enabled, and GitHub masks secret values in logs.
- Workflow inputs and request files reach the shell only through environment
  variables and are validated: a database name may contain letters, digits,
  `_` and `-`, and the server must be a plain host name. They cannot inject
  commands.
- The temporary firewall rule allows only the runner's single IP, and only for
  the duration of the export.
- Runs never overlap on the same branch (`concurrency`), and a run never
  cancels one already in progress.
