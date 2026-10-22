# 02 — Adopt LensCore in svg_conform

Effort: **3–5 person-days**

Repository: `claricle/svg_conform`

Depends on: Card 01

## Purpose

Make one `LensCore::Report` the canonical representation of an svg_conform
validation result while preserving the current public and svgcheck-compatible
surfaces for one transition.

## Dependency and load boundary

- Add LensCore to `Gemfile` with the HTTPS Git repository and the exact Card 01
  candidate commit. Generate and commit `Gemfile.lock`; assert that its LensCore
  revision equals the handoff commit.
- Do not add an unreleased Git dependency or Bundler-only options to
  `svg_conform.gemspec`. Replacing the temporary Git pin with a released gem
  requirement belongs to the later release work.
- Load LensCore from `lib/svg_conform.rb` and expose the adapter without making
  LensCore depend on svg_conform.

## Canonical mapping

Add `SvgConform::Diagnostics::LensCoreAdapter` at
`lib/svg_conform/diagnostics/lens_core_adapter.rb` with one entry point:

```ruby
SvgConform::Diagnostics::LensCoreAdapter.call(
  validation_result,
  filename: nil,
  timestamp: nil
)
```

The adapter maps:

| svg_conform source | LensCore severity | LensCore kind |
| --- | --- | --- |
| `errors` | `error` | the issue's violation type, falling back to `validation` |
| `validity_errors` | `error` | `validity` |
| `warnings` | `warning` | the issue's violation type, falling back to `validation` |
| `infos` | `info` | the issue's violation type, falling back to `notice` |

It preserves the source collection order within those channels, maps explicit
requirement IDs without generating new IDs from messages, includes available
line/column/element-path data, carries remediation fields already exposed by
`ValidationIssue`, and converts issue data to JSON-safe primitives. An
unsupported object in context fails at the adapter boundary with a stable error
rather than leaking Ruby object inspection into JSON.

Add profile-level `specification_uri`/`specification_label` to `Profile` in
`lib/svg_conform/profile.rb`, and requirement-level
`citation_uri`/`citation_label` to `BaseRequirement` in
`lib/svg_conform/requirements/base_requirement.rb`; map both pairs in their
Lutaml YAML definitions. The adapter turns them into LensCore citations.
Existing profiles may omit them; the two new profiles may not.

## Public and transitional surfaces

- Extend `ValidationResult` with `infos`, `info_count`, and
  `to_lens_core_report(timestamp: nil)`. Include infos and validity errors in
  counts/projections without changing `valid?`: only errors and validity errors
  make a result invalid.
- Make `ValidationResult#to_h`, `#to_json`, and text output project the canonical
  report. Keep their current call signatures and retain file/reference/fix data
  as documented compatibility extensions.
- Back `ConformanceReport.from_svg_conform_result` with the same report and keep
  its current class, factory signature, and YAML shape as a deprecated legacy
  projection. Preserve the `use_svgcheck_mapping:` adapter and
  `from_svgcheck_result`; svgcheck filtering happens after canonical report
  construction and does not mutate the canonical report.
- Route `lib/svg_conform/commands/check.rb` JSON, YAML, and table output through
  LensCore renderers. The accepted CLI value `table` remains an alias for the
  human renderer for compatibility.
- Extend `ValidationContext#add_notice`,
  `ValidationContext#add_external_reference_notice`, and
  `Validation::ErrorTracker#add_notice` to accept an optional explicit
  requirement ID while preserving existing calls. Store it on the existing
  `Errors::ValidationIssue` used by the info channel. Requirements pass their
  own stable ID so infos no longer fall back to `unknown`.

Document the v1 API and transition in the proposed `docs/diagnostics.adoc`, and
update the existing `docs/api_reference.adoc` and `docs/cli_guide.adoc`. Add
focused specs at `spec/svg_conform/diagnostics/lens_core_adapter_spec.rb`,
`spec/svg_conform/validation_result_spec.rb`,
`spec/svg_conform/conformance_report_spec.rb`, and the existing command/context
spec paths used below. Add
`spec/fixtures/diagnostics/external-reference-info.svg` so the library and CLI
assertions use a small SVG that emits an ordinary informational external
reference notice without depending on later profile fixtures.

## Done when

- `Gemfile.lock` pins the exact LensCore candidate commit, while the gemspec has
  no unreleased LensCore dependency.
- One validation result containing an error, validity error, warning, and info
  produces one schema-valid report with correct validity and per-channel
  summary counts.
- The library's JSON/YAML/human paths and the ordinary `check` command render
  from that report and preserve the informational diagnostic.
- Existing `ValidationResult`, `ConformanceReport`, table-output, and svgcheck
  factory call signatures remain callable and are covered by compatibility
  specs.
- Profile and requirement citations survive YAML loading and appear in the
  canonical report; JSON-unsafe issue context fails deterministically.
- All changed Ruby passes the repository linter and the gem builds.

```sh
bundle install
bundle exec rspec spec/svg_conform/diagnostics/lens_core_adapter_spec.rb spec/svg_conform/validation_result_spec.rb spec/svg_conform/conformance_report_spec.rb spec/svg_conform/validation_context_spec.rb spec/svg_conform/commands/check_command_spec.rb
bundle exec svg_conform check spec/fixtures/diagnostics/external-reference-info.svg --profile svg_1_2_rfc --format json
bundle exec rubocop
bundle exec rake build
```

## Status

State: todo
PR: none
