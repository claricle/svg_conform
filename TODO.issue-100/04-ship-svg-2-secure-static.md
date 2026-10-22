# 04 — Ship SVG 2 secure-static

Effort: **4–6 person-days**

Repository: `claricle/svg_conform`

Depends on: Cards 02 and 03

## Purpose

Add an opt-in SVG 2 profile for the dated Candidate Recommendation's
secure-static processing mode. Reuse the shared processing-feature requirement
and the established reference classifier rather than creating a second URI
model.

## Requirement matrix

Add `config/profiles/svg_2_secure_static.yml` with the dated SVG 2 Candidate
Recommendation as its `specification_uri` and these stable errors:

| Requirement ID | Rule | Normative citation |
| --- | --- | --- |
| `svg2.secure_static.script` | Reject script elements and event-handler attributes. | `https://www.w3.org/TR/2026/CR-SVG2-20261006/conform.html#secure-static-mode` |
| `svg2.secure_static.animation` | Reject SVG/CSS animation and animation-timing features. | `https://www.w3.org/TR/2026/CR-SVG2-20261006/conform.html#secure-static-mode` |
| `svg2.secure_static.interaction` | Reject interaction-only event and cursor behavior. | `https://www.w3.org/TR/2026/CR-SVG2-20261006/conform.html#secure-static-mode` |
| `svg2.secure_static.external_reference` | Permit same-document fragment references and supported self-contained data URLs; reject references that require another document, local file, or network resource. | `https://www.w3.org/TR/2026/CR-SVG2-20261006/conform.html#secure-static-mode` |

The first three rows configure Card 03's
`ProcessingFeaturesRequirement`; do not fork the class or its YAML shape for
SVG 2.

## Reference boundary

Add `ExternalReferencesRequirement` at
`lib/svg_conform/requirements/external_references_requirement.rb`. It calls the
existing public API unchanged:

```ruby
SvgConform::References::ReferenceClassifier.classify(
  href_value,
  element_name:,
  attribute_name:,
  line_number: nil,
  column_number: nil
)
```

Keep `InternalFragmentReference`, `DataUriReference`, `UrnReference`,
`ExternalUrlReference`, and `RelativePathReference` as the returned types, and
keep `LinkValidationRequirement` on the same classifier. Add behavior to
`DataUriReference` rather than introducing a second data-URL parser.

The requirement inspects:

- `href`, `xlink:href`, and SVG URI/IRI-bearing presentation attributes;
- CSS `url(...)` and `@import` tokens in style attributes and style elements;
- `xml-stylesheet` processing instructions via Card 03's source hook.

Classification is explicit:

- `#fragment` in the current document is allowed; the existing link requirement
  still reports a missing fragment target.
- HTTP(S), protocol-relative URLs, URNs, and relative paths with a resource
  component (including `other.svg#id`) are rejected.
- A data URL is allowed only when it decodes without external access and its
  media type is `image/png`, `image/jpeg`, or `image/svg+xml`. Raster payloads
  must be non-empty and syntactically decodable; an SVG payload must decode to
  one complete well-formed SVG document. Both base64 and percent-encoded forms
  are covered. Malformed encodings, unsupported media types, and nested external
  references in SVG data URLs are rejected.
- Empty references and non-resource lexical values retain their existing
  classifier behavior and are not reclassified merely to satisfy this profile.

Nested `image/svg+xml` validation applies the external-reference rule with a
depth limit and cycle guard, but does not recursively run the entire parent
profile. It reports the outer source location and a JSON-safe nested failure
reason.

## Corpus, tests, and documentation

Create `spec/fixtures/profiles/svg_2_secure_static/` with a small, enumerated
corpus:

- valid same-document fragments;
- valid base64 and percent-encoded PNG/JPEG data URLs;
- valid base64 and percent-encoded self-contained SVG data URLs;
- invalid HTTP(S), protocol-relative, relative-file, file-like fragment, URN,
  CSS `url`, CSS `@import`, and XML-stylesheet references;
- invalid malformed/unsupported data URLs and SVG data URLs with malformed XML,
  nested external content, or excessive nesting;
- one invalid fixture per script, animation, and interaction row.

Extend the existing `spec/svg_conform/references/reference_classifier_spec.rb`,
`spec/svg_conform/references/integration_spec.rb`, and
`spec/svg_conform/requirements/link_validation_requirement_spec.rb`. Add
`spec/svg_conform/references/data_uri_reference_spec.rb`,
`spec/svg_conform/requirements/external_references_requirement_spec.rb`, and
`spec/svg_conform/profiles/svg_2_secure_static_profile_spec.rb`. Run the corpus
through DOM and SAX paths and compare validity, stable IDs, and citations. Update
the existing `docs/profiles.adoc` and `docs/cli_guide.adoc` with the exact
accepted-reference table,
dated citation, profile non-goals, and example command.

## Done when

- `svg_2_secure_static` is discoverable and opt-in; no existing profile or
  default selection changes.
- All four matrix rows have stable IDs, the dated secure-static citation,
  isolated invalid fixtures, and matching DOM/SAX reports.
- Same-document fragments and all six supported data-URL form/media
  combinations pass, while every enumerated external or malformed case fails
  with `svg2.secure_static.external_reference`.
- `ReferenceClassifier.classify` retains its signature and typed returns;
  existing `LinkValidationRequirement` integration specs continue to pass.
- Processing-feature behavior comes from the unchanged serialized requirement
  introduced by Card 03.
- Documentation describes secure-static resource behavior without claiming
  complete SVG 2 document, rendering, or CSS conformance.
- All changed Ruby passes the repository linter and the gem builds.

```sh
bundle exec rspec spec/svg_conform/references/reference_classifier_spec.rb spec/svg_conform/references/data_uri_reference_spec.rb spec/svg_conform/references/integration_spec.rb spec/svg_conform/requirements/link_validation_requirement_spec.rb spec/svg_conform/requirements/external_references_requirement_spec.rb spec/svg_conform/requirements/processing_features_requirement_spec.rb spec/svg_conform/profiles/svg_2_secure_static_profile_spec.rb spec/svg_conform/commands/profiles_command_spec.rb
bundle exec svg_conform check spec/fixtures/profiles/svg_2_secure_static/valid/same-document-fragment.svg --profile svg_2_secure_static --format json
bundle exec rubocop
bundle exec rake build
```

## Status

State: todo
PR: none
