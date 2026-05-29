# Nestify Fork Changelog

This file tracks Nestify-specific releases of the `syncfusion_flutter_calendar` fork. See `CHANGELOG.md` for the upstream Syncfusion changelog and `PATCHES.md` for the patch list.

## v32.1.23+nestify.1 — Initial fork import

Base: upstream `32.1.23`

Imported the existing Nestify vendor copy from the `Nestify` mono-repo
(`mobile/third_party/syncfusion_flutter_calendar`) into this dedicated fork
repo. All seven patches (SF-1 … SF-7) listed in `PATCHES.md` are included.

This is a behavior-preserving migration: byte-identical to the prior vendor
copy. The mono-repo no longer carries the source; it pins this tag via a `git:`
dependency.
