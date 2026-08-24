# Copyparty Direct Upload Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans.

**Goal:** Add a PowerShell 5.1 publisher that generates and directly uploads updater staging files to copyparty.

**Architecture:** Keep `publish-staging.ps1` as generator. A separate wrapper invokes it, streams files by HTTP PUT with copyparty headers, and publishes `manifest.json` last.

**Tech Stack:** Windows PowerShell 5.1, .NET `HttpWebRequest`, copyparty HTTP PUT API.

## Global Constraints

- Credential is a local literal placeholder and must never be printed.
- Preserve the local-only generator.
- Stop on the first failed upload.
- Publish `manifest.json` last.

### Task 1: Preserve wrapper control

**Files:** Modify `Tools/qml-runtime-launcher/scripts/publish-staging.ps1`.

- [ ] Reproduce that dot-sourced no-change execution exits its caller.
- [ ] Replace `exit 0` with `return`.
- [ ] Verify local generation remains successful.

### Task 2: Direct upload wrapper

**Files:** Create `Tools/qml-runtime-launcher/scripts/publish-staging-upload.ps1`.

- [ ] Create a local fake HTTP endpoint test that records requests.
- [ ] Verify the test fails before the wrapper exists.
- [ ] Implement option forwarding, credential validation, path-segment encoding, streamed PUT, `PW` and `Replace` headers, fail-fast handling, and manifest-last ordering.
- [ ] Verify headers, paths, body bytes, ordering, and failed-request behavior.

### Task 3: Documentation and final verification

**Files:** Modify `Tools/qml-runtime-launcher/docs/updater.md`.

- [ ] Document credential setup and invocation.
- [ ] Document manifest-last atomic publication and failure behavior.
- [ ] Run parser checks, local generation, and fake-server integration verification.
