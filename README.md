# ReqProof Audit Action

Run [ReqProof](https://reqproof.dev) verification audit on your project in GitHub Actions.

ReqProof is a formal requirements verification tool that bridges the gap between natural-language requirements and mathematical proof. This action runs `proof audit` on your repository and reports results as a GitHub step summary.

## Quick Start

```yaml
name: ReqProof Audit
on: [push, pull_request]

jobs:
  audit:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: probelabs/proof-action@v1
        with:
          fail-level: warn
```

## Inputs

| Input | Description | Default |
|-------|-------------|---------|
| `fail-level` | Severity threshold: `error`, `warn`, `info` | `warn` |
| `format` | Output format: `table`, `markdown`, `json`, `github` | `markdown` |
| `scope` | Audit scope: `full`, `baseline` | `full` |
| `check` | Run specific check(s), comma-separated | (all) |
| `stage` | Run checks for specific stage(s), comma-separated | (all) |
| `version` | ReqProof version to install | `latest` |
| `proof-path` | Path to pre-installed proof binary | (auto-install) |
| `working-directory` | Working directory | `.` |

## Outputs

| Output | Description |
|--------|-------------|
| `exit-code` | Audit exit code: `0` = pass, `1` = errors, `2` = warnings |
| `errors` | Number of audit errors |
| `warnings` | Number of audit warnings |
| `summary` | One-line audit summary |

## Examples

### Basic audit

```yaml
- uses: probelabs/proof-action@v1
```

### Strict mode (fail on warnings)

```yaml
- uses: probelabs/proof-action@v1
  with:
    fail-level: warn
```

### Errors only (warnings do not fail the build)

```yaml
- uses: probelabs/proof-action@v1
  with:
    fail-level: error
```

### Only check specific stage

```yaml
- uses: probelabs/proof-action@v1
  with:
    stage: spec
    fail-level: error
```

### Run specific checks

```yaml
- uses: probelabs/proof-action@v1
  with:
    check: annotation_validity,coverage_threshold
    fail-level: error
```

### With solver caching

```yaml
- uses: actions/cache@v4
  with:
    path: ~/.proof/solvers
    key: proof-solvers-${{ runner.os }}
- uses: probelabs/proof-action@v1
```

### With index caching for faster re-runs

```yaml
- uses: actions/cache@v4
  with:
    path: |
      ~/.proof/solvers
      .proof/index.db
    key: proof-${{ runner.os }}-${{ hashFiles('specs/**/*.req.yaml') }}
    restore-keys: |
      proof-${{ runner.os }}-
- uses: probelabs/proof-action@v1
```

### Use outputs in subsequent steps

```yaml
- uses: probelabs/proof-action@v1
  id: audit
  continue-on-error: true
  with:
    fail-level: error

- name: Comment on PR
  if: github.event_name == 'pull_request' && steps.audit.outputs.exit-code != '0'
  uses: actions/github-script@v7
  with:
    script: |
      github.rest.issues.createComment({
        issue_number: context.issue.number,
        owner: context.repo.owner,
        repo: context.repo.repo,
        body: `ReqProof Audit: ${{ steps.audit.outputs.summary }}`
      })
```

### Pre-installed binary (e.g., from a previous step)

```yaml
- name: Install proof manually
  run: |
    curl -sL https://github.com/probelabs/proof/releases/latest/download/proof_linux_amd64.tar.gz | tar xz
    sudo install proof /usr/local/bin/proof

- uses: probelabs/proof-action@v1
  with:
    proof-path: /usr/local/bin/proof
```

### Monorepo with subdirectory

```yaml
- uses: probelabs/proof-action@v1
  with:
    working-directory: services/auth
```

## How It Works

1. **Install**: The action installs the `proof` CLI via Homebrew tap (`probelabs/proof`) or falls back to downloading the binary directly from GitHub releases.
2. **Detect**: It checks for `reqproof.yaml`, `proof.yaml`, or a `specs/` directory. If none are found, the audit is skipped with a warning (exit code 0).
3. **Audit**: Runs `proof audit` with the configured inputs.
4. **Report**: When format is `markdown`, the audit output is written to the GitHub step summary for easy viewing.
5. **Exit**: Returns the audit exit code so the workflow step fails appropriately.

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | Audit passed (or skipped for non-ReqProof projects) |
| `1` | Audit found errors exceeding the fail-level |
| `2` | Audit found warnings (when fail-level is `warn`) |

## License

MIT
