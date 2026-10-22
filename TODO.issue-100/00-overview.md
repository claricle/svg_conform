# Issue 100 — Spec-version profiles and shared lens diagnostics

## Outcome

Ship a versioned, zero-runtime-dependency `LensCore` diagnostics contract, make
`svg_conform` emit that contract without breaking its transitional interfaces,
and add two opt-in, corpus-backed profiles:

- SVG 1.1 Full in static processing mode.
- SVG 2 in secure static processing mode.

The work ends with a pinned LensCore candidate and an observable adoption
handoff. Publishing a LensCore gem and migrating other lens repositories are
follow-on work, not part of this issue.

## Current state

- `svg_conform` defines diagnostics in several places. `ValidationContext` and
  `ErrorTracker` collect `infos`, but `ValidationResult`,
  `ConformanceReport`, and the `check` command project only errors and warnings.
- `ValidationResult#to_h` and `#to_text`, Lutaml-backed
  `ConformanceReport`, CLI JSON/YAML/table output, and the svgcheck compatibility
  path do not share one canonical report object.
- Profiles are Lutaml models loaded from `config/profiles/*.yml`; requirements
  are registered independently in `lib/svg_conform/profile.rb`,
  `lib/svg_conform/profile_compiler.rb`, and
  `lib/svg_conform/requirements.rb`.
- Validation supports DOM and SAX requirement hooks, with SAX as the normal
  validation path. The current profiles describe project policies, not complete
  SVG 1.1 Full or SVG 2 secure-static conformance.
- `SvgConform::References::ReferenceClassifier.classify` already returns typed
  internal-fragment, data-URI, URN, external-URL, and relative-path references.
  `LinkValidationRequirement` consumes that API. Data URIs currently expose
  their media type but are not decoded or syntax-checked.
- The repository has no committed `Gemfile.lock` and no LensCore dependency.

## Target design

### One diagnostics contract

The new `claricle/lens_core` repository owns schema version `1`, Ruby value
objects, JSON/YAML parsers, and JSON/YAML/human renderers. A report carries its
schema version, producer, profile identity, validity, summary counts, and an
ordered diagnostics collection. A diagnostic has a stable severity, extensible
kind, stable requirement ID, message, optional citations/remediation/context,
and an optional typed location that can represent XML coordinates or binary
offsets/records.

`svg_conform` constructs that report once. Existing hashes, text/table output,
`ConformanceReport`, and svgcheck-compatible output become projections or
adapters over it for one transition. The adapter preserves all four existing
channels: errors, validity errors, warnings, and infos.

### Profiles as explicit requirement matrices

Each profile has stable requirement IDs, normative citations, expected failure
behavior, DOM/SAX coverage, focused fixtures, and documentation. SVG 1.1 Full
uses the pinned 2011 Recommendation and its flat DTD, plus the Recommendation's
Appendix G.2 handling and referenced CSS/XML-stylesheet rules. SVG 2 uses the
pinned Candidate Recommendation and enforces secure-static processing,
including its external-resource boundary.

The profiles are additive and opt-in. Existing profile behavior and the default
profile do not change.

## Work sequence

| Card | Work item | Depends on | Effort |
| --- | --- | --- | --- |
| 01 | Build LensCore diagnostics v1 | — | 4–7 person-days |
| 02 | Adopt LensCore in svg_conform | 01 | 3–5 person-days |
| 03 | Ship SVG 1.1 Full/static | 02 | 8–12 person-days |
| 04 | Ship SVG 2 secure-static | 02, 03 shared processing/source plumbing | 4–6 person-days |
| 05 | Freeze the candidate and adoption handoff | 01–04 | 2–4 person-days |

Overall estimate: **21–34 person-days**. The range includes implementation,
focused tests, fixtures, documentation, and integration fixes. It excludes gem
publication, work in other lens repositories, and external review latency.
Confidence is medium: the largest uncertainty is whether the existing XML stack
can perform offline SVG 1.1 DTD validation without another runtime dependency;
Card 03 resolves that with a bounded spike before implementation proceeds.

## Acceptance map

| Issue acceptance criterion | Planned evidence |
| --- | --- |
| SVG 1.1 and SVG 2 profiles ship, are documented, and each has a corpus | Cards 03 and 04 profile specs, focused fixture directories, CLI checks, and profile documentation |
| The diagnostics model is extracted, versioned, and shaped for reuse by other lenses | Cards 01 and 02 schema/model/renderer specs plus XML and binary location examples |
| A diagnostics JSON round-trip corpus is pinned | Card 05 byte-stable parse/render goldens tied to exact LensCore and svg_conform commits |
| Other lenses can adopt the shape without SVG code | Card 05 host-only check and handoff manifest; actual EMF/PNG/PostScript migrations remain separate issues |

## Scope boundaries

Included:

- LensCore schema/model/parser/renderer v1 and its zero-runtime-dependency gem.
- The svg_conform adapter and transitional aliases.
- SVG 1.1 Full/static and SVG 2 secure-static profiles.
- A pinned JSON corpus and cross-repository adoption handoff.

Excluded:

- EMF, PNG, or PostScript implementation, fixtures, dependency changes, and
  releases.
- Publishing LensCore or replacing its temporary Git pin with a released gem.
- SVG 1.1 Tiny/Basic profiles. They are a future sibling profile of
  `svg_1_1_full_static`, to be added once the SVG 1.1 Mobile Profiles
  specification is available as reference material; the repository's available
  Tiny reference is for SVG Tiny 1.2.
- Complete SVG 2 document/rendering conformance beyond secure-static processing.
- Profile inheritance or a redesign of existing profile discovery.
- Full-suite, full-corpus, or fuzz testing for this issue.

## Normative sources

- SVG 1.1 Second Edition Recommendation:
  <https://www.w3.org/TR/2011/REC-SVG11-20110816/>
- SVG 1.1 conformance criteria:
  <https://www.w3.org/TR/2011/REC-SVG11-20110816/conform.html#ConformingSVGDocuments>
- SVG 1.1 flat DTD:
  <https://www.w3.org/Graphics/SVG/1.1/DTD/svg11-flat-20110816.dtd>
- CSS 2 core grammar referenced by SVG 1.1:
  <https://www.w3.org/TR/2008/REC-CSS2-20080411/grammar.html>
- Associating Style Sheets with XML 1.0:
  <https://www.w3.org/TR/1999/REC-xml-stylesheet-19990629/>
- SVG 2 Candidate Recommendation snapshot:
  <https://www.w3.org/TR/2026/CR-SVG2-20261006/>
- SVG 2 secure-static processing mode:
  <https://www.w3.org/TR/2026/CR-SVG2-20261006/conform.html#secure-static-mode>

## Verification policy

Each card names only focused specs, fixture checks, lint, and build commands.
No card requires a full test suite, a corpus sweep, or fuzzing. Commands are run
in the repository named by the card.
