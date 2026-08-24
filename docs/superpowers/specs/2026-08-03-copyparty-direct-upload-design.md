# Copyparty Direct Staging Upload Design

## Goal

Add a local PowerShell entry point that generates an updater staging drop and uploads it directly to the configured copyparty staging volume. Keep the existing generator usable without network access.

## Interface

Add `Tools/qml-runtime-launcher/scripts/publish-staging-upload.ps1`. It contains a clearly marked local `$CopypartyCredential = "REPLACE_ME"` literal and refuses to run until changed. It forwards generation options to `publish-staging.ps1`. The existing script remains the local-only entry point.

## Upload flow

1. Run the existing staging generator.
2. Enumerate generated files.
3. Upload payload files and `version.txt` with streaming HTTP PUT.
4. Send `PW` for authentication and `Replace: 1` for overwrite semantics.
5. URL-encode every relative path segment while preserving `/` separators.
6. Upload `manifest.json` last.

Publishing the manifest last is the release boundary: clients continue seeing the previous manifest until all files for the new manifest are available. Any failed request stops publication and reports the failed path.

## Compatibility and safety

Use Windows PowerShell 5.1-compatible .NET HTTP APIs and stream files rather than loading binaries into memory. Change the generator no-change path from `exit 0` to `return` so invoking it from the upload wrapper cannot terminate the caller. Keep credentials out of output and request URLs. The credential-bearing script is intended to remain local and untracked.

## Verification

Use a local HTTP listener as a fake copyparty endpoint. Verify `PW` and `Replace` headers, path encoding, binary body integrity, failure handling, and that `manifest.json` is the final request. Also rerun local staging generation to guard existing behavior.

## Documentation

Update `Tools/qml-runtime-launcher/docs/updater.md` with credential setup, direct-upload usage, publication ordering, and failure behavior.
