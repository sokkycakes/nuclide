---
title: Godot Export + Play silently stops after adding Native Sky
date: 2026-09-13
status: resolved-with-regression-test
component: Stiletto Godot editor addon
---

## Symptom and evidence

Export + Play compiled the staged MapC but neither updated the runtime world nor launched FTE. A fresh headless export worked. The running editor log (`worldsrc/build/side-editor-desktop.log`) showed `Nonexistent function 'is_empty' in base 'Nil'` at `export_world`, followed by missing dictionary key `ok` in `play_current`.

## Cause and fix

The scene was already open when `native_sky` was added to its tool script. Godot's live script reload left that property unset on the existing instance despite its declared String default. Directly calling `root.native_sky.is_empty()` aborted export. The caller then assumed the returned dictionary contained `ok`, causing a second error and leaving the panel blank.

The exporter now reads Native Sky as a Variant and accepts it only when it is a nonempty String. Unset values use the normal world-property/environment fallback. The plugin guards missing results, reports scene-save failures, and shows progress before work starts. Status messages are printed to Godot's Output panel and appended to `worldsrc/build/editor-actions.log`.

## Verification

`addons/stiletto_tools/test_hot_reload.gd` reproduces the unset property in a test-local script resource without changing source files. It verifies environment export, fallback to `world_properties.skyname`, and precedence of an explicit Native Sky. The normal exporter regression test also passes. Saved scene contents and the user's running editor are preserved.
