# Issue 100 — Progress and handoff

## Current state

Planning is complete. Implementation has not started, and every work card is
`todo` with no PR. The execution order is:

| Card | State | Effort | Next dependency |
| --- | --- | --- | --- |
| 01 — Build LensCore diagnostics v1 | todo | 4–7 person-days | none |
| 02 — Adopt LensCore in svg_conform | todo | 3–5 person-days | Card 01 candidate commit |
| 03 — Ship SVG 1.1 Full/static | todo | 8–12 person-days | Card 02 adapter/citations |
| 04 — Ship SVG 2 secure-static | todo | 4–6 person-days | Card 02 diagnostics and Card 03 shared plumbing |
| 05 — Freeze the candidate and adoption handoff | todo | 2–4 person-days | Cards 01–04 complete |

Overall: **21–34 person-days**.

The next action is Card 01. Card 02 must pin a real candidate commit before SVG
integration starts; Card 05 replaces that temporary pin with the final frozen
candidate commit.

## Known implementation questions

- Card 03 must establish whether the existing Moxml/Leptris stack can perform
  validating, offline SVG 1.1 DTD checks. Its four-probe spike has explicit
  selection criteria and owns any dependency decision; no parser library is
  assumed in advance.
- SVG 1.1 source-sensitive rules require original declarations, doctypes, and
  processing instructions. Card 03 owns the source hook for both DOM and SAX so
  the implementation does not infer these from an already-normalized tree.
- The dated SVG 2 source is remote normative material. Card 04 pins citations
  and fixture behavior; it does not copy an untracked local snapshot into the
  profile.

## Scope deliberately left out

This plan's scope is LensCore, svg_conform adoption, and the two SVG profiles.
The following are outside it:

- **Actual EMF, PNG, and PostScript migrations, dependencies, and report
  goldens.** Those belong to their separate tracker issues. Card 05 supplies the
  exact LensCore commit, schema digest, SVG exports, host-only proof, and generic
  binary-location example they need, without claiming those repositories have
  adopted the contract.
- **PNG-specific full-report migration, inaccessible-field work, and a
  PNG-only RuboCop command.** No PNG files are in scope, so inventing PNG API or
  fixture requirements here would be unverified cross-repository design.
- **EMF spec paths that do not exist in the target repository.** The plan does
  not cite or require nonexistent tests; the format-neutral binary example is
  the only evidence needed for this contract issue.
- **PostScript implementation.** The final scope excludes it entirely, so there
  is no placeholder adapter or speculative field map.
- **Lens-family release and dependency audit commands.** Publishing LensCore,
  replacing temporary Git pins with a released gem constraint, changing every
  lens gemspec/lockfile, and running their release checks happen after this
  issue. Card 05 ends at an immutable, ready-to-tag candidate and observable
  handoff.

## Verification handoff

The commands on Cards 01–05 are prospective implementation checks. They are
focused by design: targeted specs and fixtures, changed-repository RuboCop, and
gem builds only. No full suite, corpus sweep, or fuzzer is required. Card 05 is
the final integration gate and must record immutable commits and digests rather
than branch names.
