# 01 — Build LensCore diagnostics v1

Effort: **4–7 person-days**

Repository: `claricle/lens_core` (new)

## Purpose

Create the independent, zero-runtime-dependency gem that owns the shared
diagnostics wire format and all of its renderers. It must be useful without
loading svg_conform or any document-format implementation.

## Contract

Schema version `1` defines these public concepts:

- `LensCore::Report`: `schema_version`, producer name/version, profile ID and
  citations, validity, summary counts, ordered diagnostics, and an optional
  caller-supplied timestamp.
- `LensCore::Diagnostic`: severity (`error`, `warning`, or `info`), extensible
  kind, stable requirement ID, message, citations, optional remediation,
  JSON-safe context, and optional location.
- `LensCore::Citation`: required absolute `uri` and optional human label.
- `LensCore::Location`: an explicit location type plus applicable fields. XML
  locations can carry line, column, and path; binary locations can carry byte
  offset, byte length, record index, and record type. Absent coordinates are
  omitted rather than populated with invented zeroes.

The schema rejects an unsupported major schema version but permits new
diagnostic `kind` values and unknown additive object members so compatible v1
producers can evolve. Parsers return stable LensCore error classes for malformed
JSON/YAML, unsupported versions, schema violations, unsafe YAML tags, and
non-UTF-8 text.

Rendering rules are deterministic: diagnostic input order is preserved,
standard object keys follow schema order, extension keys are lexical, summary
counts are derived from diagnostics, and timestamps appear only when supplied.
JSON parsing followed by JSON rendering is byte-stable for canonical inputs.

## Files and implementation

- Add `lens_core.gemspec`, `Gemfile`, `Rakefile`, and `lib/lens_core.rb`. The
  gemspec has no runtime dependencies; implementation uses Ruby's JSON, YAML,
  and time facilities.
- Add value objects in:
  - `lib/lens_core/report.rb`
  - `lib/lens_core/diagnostic.rb`
  - `lib/lens_core/citation.rb`
  - `lib/lens_core/location.rb`
- Add `lib/lens_core/parsers/json.rb` and `yaml.rb`, and matching renderers in
  `lib/lens_core/renderers/json.rb`, `yaml.rb`, and `human.rb`. Keep validation
  and canonicalization shared rather than reimplemented in each format.
- Add the normative machine-readable schema at
  `schemas/lens-diagnostics-v1.json` and document field semantics, compatibility
  rules, omission/null behavior, ordering, UTF-8 handling, and failure classes
  in `docs/diagnostics-v1.adoc`.
- Add `spec/lens_core/report_spec.rb`, `spec/lens_core/parsers_spec.rb`,
  `spec/lens_core/renderers_spec.rb`, and `spec/lens_core/schema_spec.rb`, with
  small fixtures under `spec/fixtures/v1/`. Include XML-location and
  binary-location reports to prove the contract is not SVG-shaped; these are
  format-neutral examples, not claims that another lens has adopted the gem.

Keep the Ruby model and JSON Schema at independently readable version constants,
so a host can report both the gem version and schema version. Do not add SVG
names, SVG requirement IDs, or dependencies on a lens repository.

## Done when

- The gem builds with zero runtime dependencies and can be required in a clean
  Ruby process.
- Schema-valid JSON and safe YAML parse to the same report model; JSON, YAML,
  and human renderers all include errors, warnings, and infos.
- Canonical JSON fixtures round-trip byte-for-byte, while malformed, unsafe,
  non-UTF-8, and unsupported-version fixtures fail with documented LensCore
  errors.
- XML and binary fixture locations survive parse/render without losing present
  coordinates or manufacturing absent ones.
- The schema, Ruby model, and documentation agree on required fields,
  compatibility behavior, ordering, timestamp handling, and omission rules.
- All changed Ruby passes the repository linter and the gem artifact builds.

```sh
bundle install
bundle exec rspec spec/lens_core/report_spec.rb spec/lens_core/parsers_spec.rb spec/lens_core/renderers_spec.rb spec/lens_core/schema_spec.rb
bundle exec rubocop
bundle exec rake build
```

## Status

State: todo
PR: none
