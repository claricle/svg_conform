# 03 — Ship SVG 1.1 Full/static

Effort: **8–12 person-days**

Repository: `claricle/svg_conform`

Depends on: Card 02

## Purpose

Add an opt-in profile for SVG 1.1 Full documents under static processing. The
profile validates the Recommendation's document grammar instead of treating an
element allow-list as standards conformance, and it behaves the same through
the repository's DOM and SAX entry points.

## Requirement matrix

Add `config/profiles/svg_1_1_full_static.yml` with this stable matrix. Every
entry carries its listed normative URI and emits an error with its own ID.

| Requirement ID | Rule | Normative citation |
| --- | --- | --- |
| `svg11.document.xml` | The source is well-formed XML and exposes its original declaration, doctype, and processing instructions to document-level validation. | `https://www.w3.org/TR/2011/REC-SVG11-20110816/conform.html#ConformingSVGDocuments` |
| `svg11.document.root` | The document element is `svg` in `http://www.w3.org/2000/svg`. | `https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#SVGElement` |
| `svg11.document.version` | The root declares SVG version `1.1`. | `https://www.w3.org/TR/2011/REC-SVG11-20110816/struct.html#SVGElementVersionAttribute` |
| `svg11.document.grammar` | After the Appendix G.2 foreign-namespace transform, elements, attributes, content models, and required values validate against the pinned SVG 1.1 Full flat DTD. | `https://www.w3.org/TR/2011/REC-SVG11-20110816/conform.html#ConformingSVGDocuments` |
| `svg11.document.css2` | Style attributes and style sheets accepted by the document conform to the CSS 2 core grammar required by SVG 1.1; this checks syntax, not browser rendering or every CSS property semantic. | `https://www.w3.org/TR/2008/REC-CSS2-20080411/grammar.html` |
| `svg11.document.xml_stylesheet` | `xml-stylesheet` processing instructions obey their Recommendation's pseudo-attribute syntax and SVG applicability rules. | `https://www.w3.org/TR/1999/REC-xml-stylesheet-19990629/` |
| `svg11.processing.script` | Static mode rejects script elements and event-handler attributes. | `https://www.w3.org/TR/2011/REC-SVG11-20110816/conform.html#ConformingSVGViewers` |
| `svg11.processing.animation` | Static mode rejects SVG animation elements and animation-timing attributes. | `https://www.w3.org/TR/2011/REC-SVG11-20110816/conform.html#ConformingSVGViewers` |
| `svg11.processing.interaction` | Static mode rejects interaction-only event attributes and cursor behavior. | `https://www.w3.org/TR/2011/REC-SVG11-20110816/conform.html#ConformingSVGViewers` |

The profile's `specification_uri` is the dated SVG 1.1 Second Edition
Recommendation. Profile and requirement citations flow into LensCore reports.

## Source-level validation plumbing

Document conformance needs bytes that parsed DOMs can discard. Add an optional
`source` and `source_path` to `ValidationContext`, retain the original content
in `Document`, and pass `SaxDocument#content` into `SaxValidationHandler`.
Extend `BaseRequirement` with a no-op
`validate_source(source, context)` hook. Invoke it exactly once before DOM
traversal or SAX element dispatch; source diagnostics then share the normal
tracker and LensCore adapter.

For `Document.from_node`, serialize the node and mark the source as serialized
so a source-sensitive requirement can report that a declaration/doctype/PI
claim cannot be proved instead of silently accepting it. File and string entry
points retain exact input bytes. Add focused parity specs for file and string
entry points in both modes.

## Validators and shared processing requirement

- Vendor the dated flat DTD at
  `data/svg_1_1/svg11-flat-20110816.dtd`. Add
  `data/svg_1_1/manifest.yml` with its W3C source URL, retrieval date, and
  computed SHA-256. Resolution is local-only: external entity or network access
  during validation is an error.
- Add `SvgConform::Validation::Svg11DocumentConformance` in
  `lib/svg_conform/validation/svg_1_1_document_conformance.rb` and expose it
  through `Svg11DocumentRequirement`. Implement the Appendix G.2 transform in
  an isolated helper and validate the transformed copy; never rewrite the
  caller's document.
- Add a focused CSS 2 core tokenizer/parser at
  `lib/svg_conform/validation/css2_core_grammar.rb` and reuse it for style
  attributes, style elements, and applicable stylesheet content. Keep property
  support and rendering semantics outside this syntax check.
- Add `ProcessingFeaturesRequirement` in
  `lib/svg_conform/requirements/processing_features_requirement.rb`. Its YAML
  configuration names `script`, `animation`, and `interaction` categories and
  their separate IDs/citations. Implement DOM and SAX paths once here. Card 04
  consumes the same serialized requirement unchanged.
- Require both new requirement files from `lib/svg_conform/requirements.rb` and
  include them in `SvgConform::Requirements.all`. The existing
  `Profile::REQUIREMENTS_CLASS_MAP` discovers their files, and
  `ProfileCompiler` loads and precomputes them; cover those existing mechanisms
  in the profile spec rather than adding a competing registry.

### Open implementation question resolved by this card

Before building the grammar validator, run four tiny probes (valid document,
invalid content model, external-entity attempt, and Appendix G.2 foreign
content) against the currently bundled Moxml/Leptris stack. Record the result in
the validator spec. If that stack cannot perform offline validating-DTD checks,
select the smallest maintained Ruby-compatible validating XML library, add it
to `svg_conform.gemspec` and `Gemfile`, and lock it. Selection criteria are the
four probes, supported Ruby versions, no network/entity resolution, and no
shelling out. Do not substitute a hand-maintained element list for DTD
validation.

## Corpus, tests, and documentation

Create `spec/fixtures/profiles/svg_1_1_full_static/` with small fixtures that
isolate each matrix row:

- valid minimal Full, CSS, XML-stylesheet, and foreign-metadata documents;
- invalid malformed-XML source (for `svg11.document.xml`), root/namespace,
  version, DTD content-model, attribute, CSS grammar, and XML-stylesheet cases;
- one invalid script, animation, and interaction case.

Add `spec/svg_conform/validation/svg_1_1_document_conformance_spec.rb`,
`spec/svg_conform/validation/css2_core_grammar_spec.rb`,
`spec/svg_conform/requirements/svg_1_1_document_requirement_spec.rb`,
`spec/svg_conform/requirements/processing_features_requirement_spec.rb`, and
`spec/svg_conform/profiles/svg_1_1_full_static_profile_spec.rb`. The profile spec
runs every fixture through DOM and SAX, compares validity and stable requirement
IDs, and asserts that all errors have the normative citation. Update
the existing `docs/profiles.adoc`, `docs/cli_guide.adoc`, and the profile-list
command coverage with
the profile ID, scope, citations, non-goals, and example command.

## Done when

- `svg_1_1_full_static` is discoverable and opt-in; no existing profile or
  default selection changes.
- All nine matrix rows have a stable ID, normative citation, isolated invalid
  fixture, and matching DOM/SAX result.
- Valid SVG 1.1 Full fixtures pass local DTD, CSS, and stylesheet checks without
  network access; invalid grammar is rejected by the appropriate requirement.
- Appendix G.2 foreign content is handled on a validation copy, and an external
  entity attempt cannot read a file or make a network request.
- Script, animation, and interaction categories are enforced by the serialized
  shared `ProcessingFeaturesRequirement` in both validation modes.
- Profile documentation states exactly what Full/static covers and does not
  claim Tiny, Basic, rendering, or remediation support.
- All changed Ruby passes the repository linter and the gem builds.

```sh
bundle exec rspec spec/svg_conform/validation/svg_1_1_document_conformance_spec.rb spec/svg_conform/validation/css2_core_grammar_spec.rb spec/svg_conform/requirements/svg_1_1_document_requirement_spec.rb spec/svg_conform/requirements/processing_features_requirement_spec.rb spec/svg_conform/profiles/svg_1_1_full_static_profile_spec.rb spec/svg_conform/commands/profiles_command_spec.rb
bundle exec svg_conform check spec/fixtures/profiles/svg_1_1_full_static/valid/minimal-full.svg --profile svg_1_1_full_static --format json
bundle exec rubocop
bundle exec rake build
```

## Status

State: todo
PR: none
