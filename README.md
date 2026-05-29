# Nestify Fork — `syncfusion_flutter_calendar`

This is a [Nestify-Labs](https://github.com/Nestify-Labs) fork of
[`syncfusion_flutter_calendar`](https://pub.dev/packages/syncfusion_flutter_calendar)
carrying a curated set of patches against the upstream pub.dev package. It is
consumed by the Nestify mobile app via a `git:` dependency in
`mobile/pubspec.yaml`.

## Where to look

| File | Purpose |
|---|---|
| [`PATCHES.md`](./PATCHES.md) | Branch / tag model, patch list (SF-1 … SF-7), upgrade procedure, local dev workflow. **Start here for any fork-related work.** |
| [`CHANGELOG.nestify.md`](./CHANGELOG.nestify.md) | Nestify-specific release log (per `v<...>+nestify.<n>` tag). |
| [`CHANGELOG.md`](./CHANGELOG.md) | Upstream Syncfusion changelog (unchanged). |
| [`UPSTREAM-README.md`](./UPSTREAM-README.md) | Original Syncfusion README. |

## Branches

- `main` — Nestify patches applied on top of the latest pristine upstream. This is the branch the Nestify mono-repo pins via tag.
- `upstream/33.2.x` — Pristine `33.2.8`, byte-identical to the pub.dev tarball. Reserved for upstream-only content; **never carries Nestify patches**.
- `upstream/32.1.x` — Previous baseline pristine `32.1.23`, retained for archival reference.

## Current baseline

- Upstream version: **33.2.8**
- Current tag: see latest `v33.2.8+nestify.<n>` in [Releases](../../releases) / [Tags](../../tags).

## License

Upstream Syncfusion license applies (see [`LICENSE`](./LICENSE)). This is a commercial package — to use it you need a Syncfusion commercial license or the free [Community license](https://www.syncfusion.com/products/communitylicense).
