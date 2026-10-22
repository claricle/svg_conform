# 05 — Freeze the candidate and adoption handoff

Effort: **2–4 person-days**

Repositories: `claricle/lens_core`, then `claricle/svg_conform`

Depends on: Cards 01–04

## Purpose

Freeze the v1 candidate against real svg_conform output, pin the round-trip
corpus, and leave enough format-neutral evidence for another lens to adopt
LensCore without loading SVG code. The endpoint is ready to tag; gem publication
and adopter migrations are outside this issue.

## Golden corpus

In LensCore, add:

- `spec/fixtures/v1/golden/svg_conform/svg-1.1-invalid-grammar.json`, exported
  from the Card 03 invalid grammar fixture;
- `spec/fixtures/v1/golden/svg_conform/svg-2-external-reference.json`, exported
  from the Card 04 external-reference fixture;
- `spec/fixtures/v1/golden/svg_conform/svg-four-channel-library.json`, exported
  through the public adapter from a focused result containing an error, validity
  error, warning, and info;
- `spec/fixtures/v1/golden/examples/xml-location.json` and
  `binary-location.json`, format-neutral examples that exercise the two location
  forms without claiming adoption by another lens;
- `spec/fixtures/v1/golden/manifest.yml`, recording each file's SHA-256,
  producer/version, source fixture, schema version, exact svg_conform commit for
  SVG exports, and the exact pre-freeze LensCore contract commit used to render
  them.

All goldens omit timestamps. Add `script/refresh_svg_goldens`, which takes an
svg_conform checkout path, refuses a checkout whose HEAD does not match the
manifest's expected commit, invokes the public adapter/renderers, canonicalizes
through LensCore, and updates only the three SVG JSON files and their hashes.
The script must not clone, fetch, publish, or write outside LensCore.

## Freeze and host-only evidence

- Add `spec/lens_core/round_trip_spec.rb` for canonical value and formatting
  round trips, and add `spec/lens_core/golden_corpus_spec.rb` to validate every
  manifest entry against the v1 schema, parse it, render it, and compare bytes
  with the input. Also prove that summary counts equal the diagnostics and that
  profile, citation, context, remediation, and present location fields survive.
- Add a minimal fixture app at `spec/fixtures/host_app/` whose bundle contains
  only LensCore and Ruby standard libraries. Its check reads the complete golden
  directory, reports profile/count/location information, and never requires
  svg_conform; exercise it from `spec/lens_core/host_only_spec.rb`.
- Commit the LensCore corpus, checks, and documentation as the immutable freeze
  candidate. Do not try to write that commit's own SHA into a file in the same
  commit.
- In svg_conform, update the `Gemfile` Git ref and generated `Gemfile.lock` to
  that final LensCore freeze commit. Add `docs/lens_core_handoff.adoc` with the
  exact LensCore freeze commit, schema path and SHA-256, golden manifest path,
  canonical parse/render calls, compatibility/error rules, and the exact
  earlier svg_conform producer commit named by the manifest. Explicitly label
  the binary report as a contract example, not PNG/EMF/PostScript implementation
  evidence.
- Re-run the Card 02 adapter specs and the two profile specs against that exact
  freeze commit; no API/schema shim may remain only in an uncommitted LensCore
  checkout.

If the SVG exports reveal a contract defect, fix schema/model/docs together and
commit the corrected LensCore contract first. Update svg_conform's temporary pin
and record a new producer commit, then regenerate all corpus hashes and repeat
both repositories' focused checks before declaring the later LensCore freeze
commit immutable.

## Done when

- The manifest names exact immutable generation commits and SHA-256 values for
  the schema and every golden; the svg_conform lockfile and handoff name the
  later immutable LensCore freeze commit, so no branch-only or working-tree
  dependency remains.
- Every canonical JSON golden validates and parse/renders byte-for-byte, and the
  four-channel report proves infos and validity errors are retained.
- The host-only fixture reads XML and binary location examples using LensCore
  alone and has no SVG or other-lens dependency.
- svg_conform's lockfile resolves the same frozen LensCore commit named by the
  handoff, and focused adapter/SVG 1.1/SVG 2 specs pass at that pin.
- The handoff clearly separates completed contract/SVG evidence from future
  EMF, PNG, PostScript, release, and publication work.
- LensCore and svg_conform each pass their changed-Ruby lint and gem build.

In `claricle/lens_core`:

```sh
bundle exec rspec spec/lens_core/golden_corpus_spec.rb spec/lens_core/round_trip_spec.rb spec/lens_core/host_only_spec.rb
bundle exec ruby -Ilib spec/fixtures/host_app/read_reports.rb spec/fixtures/v1/golden
bundle exec rubocop
bundle exec rake build
```

In `claricle/svg_conform`:

```sh
bundle exec rspec spec/svg_conform/diagnostics/lens_core_adapter_spec.rb spec/svg_conform/profiles/svg_1_1_full_static_profile_spec.rb spec/svg_conform/profiles/svg_2_secure_static_profile_spec.rb
bundle exec rubocop
bundle exec rake build
```

## Status

State: todo
PR: none
