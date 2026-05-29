# Nestify Fork Changelog

This file tracks Nestify-specific releases of the `syncfusion_flutter_calendar` fork. See `CHANGELOG.md` for the upstream Syncfusion changelog and `PATCHES.md` for the patch list.

## v33.2.8+nestify.1 — Upstream bump 32.1.23 → 33.2.8

Base: upstream `33.2.8` (was `32.1.23`)

Rebased all seven patches (SF-1 … SF-7) onto pristine `33.2.8`. Rebase was
clean — no upstream changes overlapped with patch regions. The cross-version
diff (`git diff upstream/32.1.x upstream/33.2.x -- lib/`) touches only 6
files (4 of them are patched files in this fork) and consists almost entirely
of a single mechanical replacement: `ResourceViewSettings.size` →
`ResourceViewSettings.width!` (the `size` property was deprecated upstream
in v33.1.47, FR29362). Nestify does not use ResourceView, so this has no
consumer impact.

Notable upstream fix carried into this baseline (not Nestify-related but worth
noting): v33.2.8 fixed duplicate appointments appearing in Month view when the
appointment count exceeds `appointmentDisplayCount` with `appointmentBuilder`.

Patch line refs updated for SF-7 anchors (`_handleLongPressStart` /
`_handleLongPressMove` / `_handleLongPressEnd`).

## v32.1.23+nestify.1 — Initial fork import

Base: upstream `32.1.23`

Imported the existing Nestify vendor copy from the `Nestify` mono-repo
(`mobile/third_party/syncfusion_flutter_calendar`) into this dedicated fork
repo. All seven patches (SF-1 … SF-7) listed in `PATCHES.md` are included.

This is a behavior-preserving migration: byte-identical to the prior vendor
copy. The mono-repo no longer carries the source; it pins this tag via a `git:`
dependency.
