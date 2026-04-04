# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build/Test Commands

```bash
# Install dependencies
bin/setup

# Run tests
rake spec

# Run a single spec file
bundle exec rspec spec/svg_conform/validator_spec.rb

# Run tests with detailed output
bundle exec rspec --format documentation

# Run linting
rake rubocop

# Run both tests and linting
rake

# Run a specific test by line number
bundle exec rspec spec/svg_conform/validator_spec.rb:42
```

## Architecture

### Two-Mode Validation System

SvgConform uses two distinct operating modes:

1. **SAX Validation Mode** (always used for validation):
   - Memory-safe streaming XML parser
   - Constant memory regardless of file size
   - Handles files of any size (tested with 100MB+)
   - Read-only, cannot modify documents
   - Implemented via `SaxDocument` and `SaxValidationHandler`

2. **DOM Remediation Mode** (only when applying fixes):
   - Full document tree loaded in memory
   - XPath queries and tree modification
   - Memory scales with file size
   - Only activated when `fix: true` is specified

### Core Classes

- `Validator` - Main entry point; normalizes all inputs to SAX validation
- `SaxDocument` - SAX-based document wrapper for memory-safe validation
- `Document` - DOM-based document wrapper for modifications
- `Profile` - Collection of requirements and remediations; loaded from YAML
- `Profiles` - Factory for loading/retrieving profile instances
- `ValidationContext` - Carries state during validation (errors, data collected)
- `ValidationResult` - Holds validation outcomes after checking
- `ConformanceReport` - Formats validation results for output

### Requirements System

Requirements validate SVG documents. All requirements must support SAX validation:

- Requirements inherit from `BaseRequirement` in `lib/svg_conform/requirements/`
- Must implement `validate_sax_element(element, context)` for immediate checks
- Can optionally implement `collect_sax_data()` + `validate_sax_complete()` for deferred validation (e.g., cross-reference checks)
- Use `context.data` hash for per-document state (not instance variables - they leak across validations)
- Never attempt DOM operations in SAX callbacks

Key requirement classes: `NamespaceRequirement`, `ViewboxRequiredRequirement`, `IdReferenceRequirement`, `ForbiddenContentRequirement`, `ColorRestrictionsRequirement`, etc.

### Remediations System

Remediations fix validation failures. They run in DOM mode:

- Inherit from `BaseRemediation` in `lib/svg_conform/remediations/`
- Linked to requirements via `targets` array in profile YAML
- Only execute when `should_execute?(failed_requirements)` returns true

### Profile Configuration

Profiles are defined in YAML under `config/profiles/`:
- `base.yml` - Common requirements shared by other profiles
- `metanorma.yml`, `svg_1_2_rfc.yml`, etc. - Specific profile definitions
- Profile class map is built dynamically from filesystem in `Profile.build_class_map`

Profiles support `import` to inherit from other profiles (e.g., `metanorma` imports `base`).

### CLI Structure

- `lib/svg_conform/cli.rb` - Thor-based CLI entry point
- `lib/svg_conform/commands/check.rb` - Main validation command
- `lib/svg_conform/commands/profiles.rb` - Profile listing command
- `lib/svg_conform/commands/svgcheck.rb` - SVGCheck compatibility subcommands

### Input Handling

The `Validator` accepts multiple input types and always uses SAX:
- String (XML content) → parsed directly with SAX
- Moxml/Nokogiri documents → serialized once, then SAX validated
- Document/Element objects → same serialization approach

This ensures memory safety for large files regardless of input type.

### Key Files

- `lib/svg_conform.rb` - Main require file with autoloads
- `lib/svg_conform/element_proxy.rb` - Lightweight SAX element representation
- `lib/svg_conform/validation_context.rb` - Validation state container
- `lib/svg_conform/sax_document.rb` - SAX document wrapper
- `lib/svg_conform/sax_validation_handler.rb` - SAX callback handler

### Error Handling Pattern

The CLI uses `exit 1` for error exits. When improving error handling, prefer raising proper Ruby exceptions (`ValidationError`, `ProfileError`, `ArgumentError`) rather than using `exit`/`abort` directly, as Thor provides mechanisms for displaying errors gracefully to users.
