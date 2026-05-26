---
phase: 15
slug: release-pipeline
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-05-26
---

# Phase 15 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Requirements Covered

| Req ID | Description |
|--------|-------------|
| REL-01 | Single workflow fires all distribution targets (GH release, Docker push, Homebrew bump) |
| REL-02 | Release is gated on green CI — ci-gate job blocks publishing if any required check failed |
| DOCK-03 | Docker image published to ghcr.io with semver tag and latest |

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | YAML structure assertions via python3 + grep |
| **Config file** | none |
| **Quick run command** | `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml'))" && echo "YAML valid"` |
| **Full suite command** | Run all bash/python3 blocks below |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run the structure assertions below
- **After every plan wave:** Run full suite
- **Before `/gsd-verify-work`:** All assertions must pass
- **Max feedback latency:** 10 seconds

---

## Per-Requirement Verification

### REL-01 — Single workflow fires all distribution targets

```bash
# ci-gate job exists
grep -q 'ci-gate:' /Users/mohandoz/u01/innovate/conjure/.github/workflows/release.yml && echo "PASS: ci-gate job present" || echo "FAIL"

# Homebrew bump step present
grep -q 'bump-homebrew-formula-action' /Users/mohandoz/u01/innovate/conjure/.github/workflows/release.yml && echo "PASS: Homebrew step present" || echo "FAIL"

# Docker push step present
grep -q 'push: true' /Users/mohandoz/u01/innovate/conjure/.github/workflows/release.yml && echo "PASS: Docker push step present" || echo "FAIL"

# Marketplace check present
grep -q 'Marketplace version check' /Users/mohandoz/u01/innovate/conjure/.github/workflows/release.yml && echo "PASS: Marketplace check present" || echo "FAIL"

# release job needs ci-gate
python3 -c "
import yaml
w = yaml.safe_load(open('/Users/mohandoz/u01/innovate/conjure/.github/workflows/release.yml'))
assert 'ci-gate' in w['jobs']['release']['needs']
print('PASS: release needs ci-gate')
"
```

---

### REL-02 — Release gated on green CI

```bash
grep -q 'ci-gate:' /Users/mohandoz/u01/innovate/conjure/.github/workflows/release.yml && echo "PASS" || echo "FAIL: ci-gate job missing"
grep -q 'needs: \[ci-gate\]' /Users/mohandoz/u01/innovate/conjure/.github/workflows/release.yml && echo "PASS" || echo "FAIL: needs missing"
grep -q 'check-runs' /Users/mohandoz/u01/innovate/conjure/.github/workflows/release.yml && echo "PASS" || echo "FAIL: check-runs API not used"
grep -q 'failure' /Users/mohandoz/u01/innovate/conjure/.github/workflows/release.yml && echo "PASS" || echo "FAIL: failure check missing"
```

---

### DOCK-03 — Docker image published to ghcr.io with semver + latest

```bash
grep -q 'ghcr.io/mohandoz/conjure' /Users/mohandoz/u01/innovate/conjure/.github/workflows/release.yml && echo "PASS" || echo "FAIL"
grep -q 'latest' /Users/mohandoz/u01/innovate/conjure/.github/workflows/release.yml && echo "PASS" || echo "FAIL: latest tag missing"
grep -q 'push: true' /Users/mohandoz/u01/innovate/conjure/.github/workflows/release.yml && echo "PASS" || echo "FAIL: push:true missing"
grep -q 'linux/amd64,linux/arm64' /Users/mohandoz/u01/innovate/conjure/.github/workflows/release.yml && echo "PASS" || echo "FAIL: multi-arch missing"
# Live check (requires released image):
# docker pull ghcr.io/mohandoz/conjure:latest
```

---

## YAML Integrity

```bash
# Validate release.yml parses without error
python3 -c "
import yaml
w = yaml.safe_load(open('/Users/mohandoz/u01/innovate/conjure/.github/workflows/release.yml'))
jobs = w['jobs']
assert 'ci-gate' in jobs, 'ci-gate job missing'
rel = jobs['release']
assert 'ci-gate' in rel.get('needs', []), 'release.needs missing ci-gate'
perms = rel.get('permissions', {})
assert perms.get('packages') == 'write', 'packages: write missing'
steps = rel.get('steps', [])
names = [s.get('name','') for s in steps]
uses_list = [s.get('uses','') for s in steps]
assert 'Verify VERSION matches tag' in names
assert 'Marketplace version check' in names
assert 'Extract CHANGELOG entry' in names
assert 'Create release' in names
assert 'Bump Homebrew formula' in names
assert any('login-action' in u for u in uses_list), 'docker login step missing'
assert any('build-push-action' in u for u in uses_list), 'build-push step missing'
bp = next(s for s in steps if 'build-push-action' in s.get('uses',''))
assert bp['with']['push'] == True, 'push: true missing'
print('PASS: release.yml structure valid')
"
```

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Pushing a `v*` tag triggers the release workflow and all jobs succeed | REL-01, REL-02 | Requires GitHub Actions runner and live secrets | Push a test tag to a fork; verify ci-gate and release jobs both complete green |
| `ghcr.io/mohandoz/conjure:v<N>` and `:latest` appear in GitHub Packages after release | DOCK-03 | Requires published image | After a release: `docker pull ghcr.io/mohandoz/conjure:latest` and `docker run --rm ghcr.io/mohandoz/conjure:latest version` |
| ci-gate fails and blocks release when CI has a red check | REL-02 | Requires GitHub Actions runner | Manually create a failing check on a tagged commit SHA and verify the release job does not run |
| Homebrew tap receives a SHA bump commit after release | REL-01 | Requires HOMEBREW_TAP_GITHUB_TOKEN secret | After release: inspect `mohandoz/homebrew-conjure` for a new commit bumping the formula |

---

## Validation Sign-Off

- [x] REL-01 verify commands documented
- [x] REL-02 verify commands documented
- [x] DOCK-03 verify commands documented
- [x] YAML integrity assertion documented
- [ ] All automated assertions pass (pending CI run)
- [ ] `nyquist_compliant: true` set in frontmatter (pending human sign-off)

**Approval:** pending
