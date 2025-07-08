# frozen_string_literal: true

require 'nokogiri'

module SvgConform
  # Semantic comparison engine for comparing validation results and remediated content
  class SemanticComparator
    # Compare validation results semantically
    def self.compare_validation_results(svg_conform_report, svgcheck_report)
      # Extract semantic features from both reports
      svg_conform_features = extract_validation_features(svg_conform_report)
      svgcheck_features = extract_validation_features(svgcheck_report)

      # Detect repair mode (both tools report valid=true)
      repair_mode = svg_conform_features[:valid] && svgcheck_features[:valid]

      # Detect mixed mode (one valid, one invalid)
      mixed_mode = svg_conform_features[:valid] != svgcheck_features[:valid]

      # Compare features semantically
      comparison = {
        overall_validity: compare_validity(svg_conform_features[:valid], svgcheck_features[:valid]),
        requirement_coverage: compare_requirement_coverage(svg_conform_features[:requirements],
                                                           svgcheck_features[:requirements]),
        semantic_issues: compare_semantic_issues(svg_conform_features[:issues], svgcheck_features[:issues],
                                                 repair_mode, mixed_mode),
        detailed_mapping: create_detailed_mapping(svg_conform_features[:issues], svgcheck_features[:issues],
                                                  repair_mode, mixed_mode),
        repair_mode: repair_mode,
        mixed_mode: mixed_mode
      }

      # Add validity_match for compatibility
      comparison[:validity_match] = comparison[:overall_validity][:match]

      # Calculate overall compatibility score
      comparison[:compatibility_score] = calculate_compatibility_score(comparison)
      comparison
    end

    # Compare remediated SVG content semantically
    def self.compare_remediated_content(svg_conform_content, svgcheck_content)
      # Parse both SVG documents
      svg_conform_doc = parse_svg_safely(svg_conform_content)
      svgcheck_doc = parse_svg_safely(svgcheck_content)

      return { error: 'Failed to parse SVG content' } if svg_conform_doc.nil? || svgcheck_doc.nil?

      # Extract semantic features from both documents
      svg_conform_features = extract_svg_features(svg_conform_doc)
      svgcheck_features = extract_svg_features(svgcheck_doc)

      # Compare features
      {
        structure_match: compare_structure(svg_conform_features[:structure], svgcheck_features[:structure]),
        attributes_match: compare_attributes(svg_conform_features[:attributes], svgcheck_features[:attributes]),
        content_match: compare_content(svg_conform_features[:content], svgcheck_features[:content]),
        namespace_match: compare_namespaces(svg_conform_features[:namespaces], svgcheck_features[:namespaces]),
        style_match: compare_styles(svg_conform_features[:styles], svgcheck_features[:styles]),
        semantic_equivalence: calculate_semantic_equivalence(svg_conform_features, svgcheck_features)
      }
    end

    # Extract validation features for semantic comparison
    def self.extract_validation_features(report)
      # Extract ALL issues (errors, warnings, infos) for semantic comparison
      issues = []

      issues.concat(report.errors.issues) if report.respond_to?(:errors) && report.errors.respond_to?(:issues)

      # For svgcheck reports, also include warnings and infos if available
      issues.concat(report.warnings.issues) if report.respond_to?(:warnings) && report.warnings.respond_to?(:issues)

      # If the report has a direct issues method, use that
      issues = report.issues if issues.empty? && report.respond_to?(:issues)

      {
        valid: report.respond_to?(:valid) ? report.valid : false,
        requirements: extract_requirement_types(issues),
        issues: group_issues_semantically(issues)
      }
    end

    # Extract requirement types from issues
    def self.extract_requirement_types(issues)
      requirement_counts = {}

      issues.each do |issue|
        req_id = issue.respond_to?(:requirement_id) ? issue.requirement_id : 'unknown'
        requirement_counts[req_id] = (requirement_counts[req_id] || 0) + 1
      end

      requirement_counts
    end

    # Group issues by semantic meaning
    def self.group_issues_semantically(issues)
      semantic_groups = {}

      issues.each do |issue|
        semantic_key = extract_semantic_key(issue)
        semantic_groups[semantic_key] ||= []
        semantic_groups[semantic_key] << issue
      end

      semantic_groups.transform_values(&:length)
    end

    # Extract semantic key from an issue
    def self.extract_semantic_key(issue)
      # Handle different issue types
      message = if issue.respond_to?(:message)
                  issue.message
                elsif issue.is_a?(Hash)
                  issue[:message] || issue['message']
                else
                  issue.to_s
                end

      # Map ONLY the exact 28 svgcheck.py log patterns to semantic keys
      case message
      # Error patterns from checksvg.py (4 patterns)
      when /^Malformed field '([^']+)' in style attribute found\. Field removed\.$/
        "malformed_style_field:#{normalize_value(::Regexp.last_match(1))}"
      when /^Malformed field '(\[[^\]]+\])' in style attribute found\. Field removed\.$/
        "malformed_style_field:#{normalize_value(::Regexp.last_match(1))}"
      when /^Malformed style declaration '([^']+)' found\. Declaration removed\.$/
        "malformed_style_field:#{normalize_value(::Regexp.last_match(1))}"
      when /^Style property '([^']+)' promoted to attribute$/
        "style_promotion:#{::Regexp.last_match(1)}"
      when /^Style property '([^']+)' removed$/
        "style_property_removed:#{::Regexp.last_match(1)}"
      when /^Error when calculating SVG size: (.+)$/
        'informative:svg_size_calculation_error'
      when /^File does not conform to SVG requirements$/
        'informative:file_nonconformant'

      # Warning patterns from checksvg.py (10 patterns)
      when /^Element '([^']+)' in namespace '([^']+)' is not allowed$/
        "invalid_element_namespace:#{::Regexp.last_match(1)}:#{normalize_namespace(::Regexp.last_match(2))}"
      when /^Element '([^']+)' not allowed$/
        "invalid_element:#{::Regexp.last_match(1)}"
      when /^Element '([^']+)' does not allow attributes with namespace '([^']+)'$/
        "namespace_violation:#{::Regexp.last_match(1)}:#{normalize_namespace(::Regexp.last_match(2))}"
      when /^The element '([^']+)' does not allow the attribute '([^']+)', attribute to be removed\.$/
        "invalid_attribute:#{::Regexp.last_match(1)}:#{::Regexp.last_match(2)}"
      when /^The attribute '([^']+)' does not allow the value '([^']+)', replaced with '([^']+)'$/
        # Normalize color values for semantic equivalence
        attribute = ::Regexp.last_match(1)
        value = ::Regexp.last_match(2)

        # For color attributes, use normalized color values
        if %w[fill stroke].include?(attribute)
          "invalid_attribute_value:#{attribute}:#{normalize_color_value(value)}"
        else
          "invalid_attribute_value:#{attribute}:#{normalize_value(value)}"
        end
      when /^The attribute '([^']+)' does not allow the value '([^']+)', attribute to be removed$/
        "invalid_attribute_value:#{::Regexp.last_match(1)}:#{normalize_value(::Regexp.last_match(2))}"
      when /^The attribute viewBox is required on the root svg element$/
        'viewbox_required'
      when /^Trying to put in the attribute with value '([^']+)'$/
        'informative:viewbox_auto_added'
      when /^The namespace ([^\s]+) is not permitted for svg elements\.$/
        "namespace_violation:element:#{normalize_namespace(::Regexp.last_match(1))}"
      when /^The element '([^']+)' is not allowed as a child of '([^']+)'$/
        "invalid_child:#{::Regexp.last_match(1)}:#{::Regexp.last_match(2)}"
      when /^Malformed namespace\. Should have errored during parsing$/
        'informative:malformed_namespace'
      when /^--no-xinclude option is deprecated and has no effect\.$/
        'informative:deprecated_option'

      # Note patterns from checksvg.py (13 patterns)
      when /^modify_style check '([^']+)' in '([^']+)'$/
        'informative:modify_style_check'
      when /^   modify_style - p=([^\s]+)  v=(.+)$/
        'informative:modify_style_processing'
      when /^value_ok look for (.+) in (.+)$/
        'informative:value_validation'
      when /^  legal value list (.+)$/
        'informative:legal_values'
      when /^ --- skip to end -- (.+)$/
        'informative:validation_skip'
      when /^Color or grayscale heuristic applied to: '([^']+)' yields shade: '([^']+)'$/
        'informative:color_heuristic'
      when /^[^\s]+ tag = (.+)$/
        'informative:element_processing'
      when /^[^\s]+ element [^:]+: (.+)$/
        'informative:element_attributes'
      when /^[^\s]+ attr ([^\s]+) = ([^\s]+) \(ns = ([^)]*)\)$/
        'informative:attribute_processing'
      when /^[^\s]+child, tag = (.+)$/
        'informative:child_processing'
      when /^Checking svg element at line (\d+) in file (.+)$/
        'informative:svg_element_check'

      # SvgConform-specific patterns that map to svgcheck semantic equivalents
      when /^Color '([^']+)' in attribute '([^']+)' is not allowed in this profile$/
        # Map SvgConform color restriction to svgcheck invalid_attribute_value pattern
        # Normalize color values to handle different formats (WHITE -> white, etc.)
        "invalid_attribute_value:#{::Regexp.last_match(2)}:#{normalize_color_value(::Regexp.last_match(1))}"
      when /^Color '([^']+)' in style property '([^']+)' is not allowed in this profile$/
        # Map SvgConform style property color restriction to svgcheck invalid_attribute_value pattern
        # Svgcheck promotes style properties to attributes, so we map accordingly
        "invalid_attribute_value:#{::Regexp.last_match(2)}:#{normalize_color_value(::Regexp.last_match(1))}"
      when /^Font family '([^']+)' is not allowed in this profile$/
        # Map SvgConform font family restriction to svgcheck invalid_attribute_value pattern
        "invalid_attribute_value:font-family:#{normalize_value(::Regexp.last_match(1))}"
      when /^Font family '([^']+)' in style is not allowed in this profile$/
        # Map SvgConform style font family restriction to svgcheck invalid_attribute_value pattern
        font_family = normalize_value(::Regexp.last_match(1))
        # Embedded font restrictions are profile differences
        if font_family.include?('embedded')
          "informative:profile_stricter_embedded_fonts:#{font_family}"
        else
          "invalid_attribute_value:font-family:#{font_family}"
        end
      when /^Font family '([^']+)' is not allowed in this profile$/
        # Map SvgConform font family restriction to svgcheck invalid_attribute_value pattern
        font_family = normalize_value(::Regexp.last_match(1))
        # Embedded font restrictions are profile differences
        if font_family.include?('embedded')
          "informative:profile_stricter_embedded_fonts:#{font_family}"
        else
          "invalid_attribute_value:font-family:#{font_family}"
        end
      when /^svg root element must have a viewbox attribute$/i
        # Map SvgConform viewBox requirement to svgcheck pattern (case insensitive)
        'viewbox_required'
      when /^Element '([^']+)' is not allowed in this profile$/
        # Map SvgConform element restriction to svgcheck invalid_child pattern
        element = ::Regexp.last_match(1)
        # Font-related and clipPath elements are profile differences, not validation errors
        if %w[font glyph font-face missing-glyph clipPath].include?(element)
          "informative:profile_stricter_elements:#{element}"
        else
          "invalid_child:#{element}:svg"
        end
      when /^The element '([^']+)' is not allowed as a child of '([^']+)'$/
        # Map SvgConform child element restriction to svgcheck pattern
        element = ::Regexp.last_match(1)
        parent = ::Regexp.last_match(2)
        # Font-related and clipPath elements as children are profile differences
        if %w[font glyph font-face missing-glyph clipPath].include?(element)
          "informative:profile_stricter_elements:#{element}:#{parent}"
        else
          "invalid_child:#{element}:#{parent}"
        end
      when /^Attribute '([^']+)' is not allowed on element '([^']+)'$/
        # Map SvgConform attribute restriction to svgcheck pattern
        "invalid_attribute:#{::Regexp.last_match(2)}:#{::Regexp.last_match(1)}"
      when /^The namespace ([^\s]+) is not permitted for svg elements\.?$/
        # Map SvgConform namespace restriction to svgcheck pattern
        "namespace_violation:element:#{normalize_namespace(::Regexp.last_match(1))}"
      when /^viewBox attribute must contain four numeric values/i
        # Map SvgConform viewBox format validation (more strict than svgcheck)
        'viewbox_format_error'

      # Everything else maps to "other" for non-svgcheck messages
      else
        "other:#{normalize_message(message)}"
      end
    end

    # Compare validity semantically
    def self.compare_validity(svg_conform_valid, svgcheck_valid)
      {
        svg_conform: svg_conform_valid,
        svgcheck: svgcheck_valid,
        match: svg_conform_valid == svgcheck_valid,
        semantic_match: true # Validity is always semantic
      }
    end

    # Compare requirement coverage
    def self.compare_requirement_coverage(svg_conform_reqs, svgcheck_reqs)
      all_requirements = (svg_conform_reqs.keys + svgcheck_reqs.keys).uniq

      coverage = {}
      all_requirements.each do |req|
        svg_count = svg_conform_reqs[req] || 0
        svgcheck_count = svgcheck_reqs[req] || 0

        coverage[req] = {
          svg_conform: svg_count,
          svgcheck: svgcheck_count,
          exact_match: svg_count == svgcheck_count,
          coverage_ratio: if svgcheck_count.positive?
                            svg_count.to_f / svgcheck_count
                          else
                            (svg_count.positive? ? Float::INFINITY : 1.0)
                          end
        }
      end

      coverage
    end

    # Compare semantic issues
    def self.compare_semantic_issues(svg_conform_issues, svgcheck_issues, repair_mode = false, _mixed_mode = false)
      all_semantic_keys = (svg_conform_issues.keys + svgcheck_issues.keys).uniq

      comparison = {}
      all_semantic_keys.each do |key|
        svg_count = svg_conform_issues[key] || 0
        svgcheck_count = svgcheck_issues[key] || 0

        # In repair mode, treat informational messages differently
        # Check if this is a repair notification by looking at the semantic key pattern
        is_repair_notification = repair_mode && (
          key.start_with?('style_promotion:', 'informative:') ||
          key.include?('replaced with') ||
          key.start_with?('invalid_attribute_value:') # These are repair notifications in repair mode
        )

        comparison[key] = if is_repair_notification
                            # Repair notifications are informational, not validation errors
                            {
                              svg_conform: svg_count,
                              svgcheck: svgcheck_count,
                              semantic_match: true, # Always consider repair notifications as matching
                              coverage: true,
                              repair_notification: true
                            }
                          else
                            {
                              svg_conform: svg_count,
                              svgcheck: svgcheck_count,
                              semantic_match: svg_count == svgcheck_count,
                              coverage: svgcheck_count.positive? ? (svg_count >= svgcheck_count) : svg_count.zero?,
                              repair_notification: false
                            }
                          end
      end

      comparison
    end

    # Create detailed mapping between issues
    def self.create_detailed_mapping(svg_conform_issues, svgcheck_issues, repair_mode = false, _mixed_mode = false)
      # In repair mode, separate validation issues from repair notifications
      if repair_mode
        svg_conform_validation = svg_conform_issues.reject do |k, _|
          k.start_with?('style_promotion:', 'informative:') || k.start_with?('invalid_attribute_value:')
        end
        svgcheck_validation = svgcheck_issues.reject do |k, _|
          k.start_with?('style_promotion:',
                        'informative:') || k.include?('replaced with') || k.start_with?('invalid_attribute_value:')
        end

        svg_conform_notifications = svg_conform_issues.select do |k, _|
          k.start_with?('style_promotion:', 'informative:') || k.start_with?('invalid_attribute_value:')
        end
        svgcheck_notifications = svgcheck_issues.select do |k, _|
          k.start_with?('style_promotion:',
                        'informative:') || k.include?('replaced with') || k.start_with?('invalid_attribute_value:')
        end

        {
          svg_conform_only: svg_conform_validation.keys - svgcheck_validation.keys,
          svgcheck_only: svgcheck_validation.keys - svg_conform_validation.keys,
          common: svg_conform_validation.keys & svgcheck_validation.keys,
          total_svg_conform: svg_conform_validation.values.sum,
          total_svgcheck: svgcheck_validation.values.sum,
          repair_notifications: {
            svg_conform: svg_conform_notifications.values.sum,
            svgcheck: svgcheck_notifications.values.sum
          }
        }
      else
        {
          svg_conform_only: svg_conform_issues.keys - svgcheck_issues.keys,
          svgcheck_only: svgcheck_issues.keys - svg_conform_issues.keys,
          common: svg_conform_issues.keys & svgcheck_issues.keys,
          total_svg_conform: svg_conform_issues.values.sum,
          total_svgcheck: svgcheck_issues.values.sum
        }
      end
    end

    # Calculate compatibility score
    def self.calculate_compatibility_score(comparison)
      # Handle mixed mode scenarios differently
      return calculate_mixed_mode_compatibility_score(comparison) if comparison[:mixed_mode]

      validity_score = comparison[:overall_validity][:match] ? 1.0 : 0.0

      # Separate validation issues from informational issues
      validation_issues = {}
      informational_issues = {}

      comparison[:semantic_issues].each do |key, issue|
        if key.start_with?('style_promotion:', 'informative:')
          informational_issues[key] = issue
        else
          validation_issues[key] = issue
        end
      end

      # Calculate semantic issues score for validation issues only
      if validation_issues.empty?
        semantic_score = 1.0
      else
        semantic_scores = validation_issues.values.map { |issue| issue[:semantic_match] ? 1.0 : 0.0 }
        semantic_score = semantic_scores.sum / semantic_scores.length
      end

      # Calculate coverage score excluding informational issues
      total_svg_conform = comparison[:detailed_mapping][:total_svg_conform]
      total_svgcheck = comparison[:detailed_mapping][:total_svgcheck]

      # Subtract informational issues from both totals
      informational_svg_conform = informational_issues.values.sum { |issue| issue[:svg_conform] }
      informational_svgcheck = informational_issues.values.sum { |issue| issue[:svgcheck] }

      validation_svg_conform_total = total_svg_conform - informational_svg_conform
      validation_svgcheck_total = total_svgcheck - informational_svgcheck

      # Coverage score: how well do we cover the validation issues?
      # If SvgConform finds more issues than svgcheck, that's not a penalty
      coverage_score = if validation_svgcheck_total.positive?
                         # Standard case: measure how much of svgcheck we cover
                         [validation_svg_conform_total.to_f / validation_svgcheck_total, 1.0].min
                       elsif validation_svg_conform_total.positive?
                         # SvgConform finds issues but svgcheck doesn't - this is fine (more strict)
                         1.0
                       else
                         # Both find no validation issues - perfect
                         1.0
                       end

      # Prioritize semantic matching over requirement categorization
      # Validity: 20%, Semantic Issues: 60%, Coverage: 20%
      (validity_score * 0.2 + semantic_score * 0.6 + coverage_score * 0.2).round(3)
    end

    # Calculate compatibility score for mixed mode scenarios
    def self.calculate_mixed_mode_compatibility_score(comparison)
      # In mixed mode, one tool succeeded and one failed
      # Focus on complementary validation rather than exact overlap

      # Separate validation issues from informational issues
      validation_issues = {}
      informational_issues = {}

      comparison[:semantic_issues].each do |key, issue|
        if key.start_with?('style_promotion:', 'informative:')
          informational_issues[key] = issue
        else
          validation_issues[key] = issue
        end
      end

      # Calculate semantic overlap score (exact matches)
      if validation_issues.empty?
        semantic_overlap_score = 1.0
      else
        semantic_matches = validation_issues.values.count { |issue| issue[:semantic_match] }
        total_unique_issues = validation_issues.size
        semantic_overlap_score = semantic_matches.to_f / total_unique_issues
      end

      # Calculate complementary validation score with improved logic
      # Give significant credit when tools detect different but valid issues
      total_svg_conform = comparison[:detailed_mapping][:total_svg_conform]
      total_svgcheck = comparison[:detailed_mapping][:total_svgcheck]

      # Subtract informational issues from both totals
      informational_svg_conform = informational_issues.values.sum { |issue| issue[:svg_conform] }
      informational_svgcheck = informational_issues.values.sum { |issue| issue[:svgcheck] }

      validation_svg_conform_total = total_svg_conform - informational_svg_conform
      validation_svgcheck_total = total_svgcheck - informational_svgcheck

      # Count common issues (both tools detected)
      common_issues = comparison[:detailed_mapping][:common].size

      # Enhanced complementary validation scoring
      # Give high credit when both tools find issues, even if different types
      complementary_score = if validation_svg_conform_total.positive? && validation_svgcheck_total.positive?
                              # Both tools found validation issues - excellent complementary coverage
                              # Base score of 0.8, with bonus for common issues
                              base_score = 0.8
                              common_bonus = common_issues.positive? ? 0.15 : 0.0
                              [base_score + common_bonus, 1.0].min
                            elsif validation_svg_conform_total.positive? || validation_svgcheck_total.positive?
                              # One tool found issues - partial coverage
                              0.7
                            else
                              # Neither found validation issues - perfect (but unlikely in mixed mode)
                              1.0
                            end

      # Mixed mode remediation success bonus - enhanced
      # In mixed mode, successful remediation by either tool is valuable
      remediation_success_bonus = if comparison[:overall_validity][:svg_conform] || comparison[:overall_validity][:svgcheck]
                                    # One tool successfully remediated the file
                                    # Higher bonus if both tools found issues but one succeeded
                                    if validation_svg_conform_total.positive? && validation_svgcheck_total.positive?
                                      0.5  # Both found issues, one succeeded - excellent
                                    else
                                      0.4  # Standard remediation success
                                    end
                                  else
                                    # Neither tool achieved validity (shouldn't happen in mixed mode)
                                    0.0
                                  end

      # Enhanced mixed mode scoring with higher weight on complementary validation
      # Semantic Overlap: 25%, Complementary Validation: 50%, Remediation Success: 25%
      # This better rewards comprehensive validation coverage
      (semantic_overlap_score * 0.25 + complementary_score * 0.5 + remediation_success_bonus * 0.25).round(3)
    end

    # Parse SVG safely
    def self.parse_svg_safely(content)
      return nil if content.nil? || content.strip.empty?

      Nokogiri::XML(content, &:strict)
    rescue Nokogiri::XML::SyntaxError
      nil
    end

    # Extract SVG features for semantic comparison
    def self.extract_svg_features(doc)
      {
        structure: extract_structure(doc),
        attributes: extract_attributes(doc),
        content: extract_content(doc),
        namespaces: extract_namespaces(doc),
        styles: extract_styles(doc)
      }
    end

    # Extract document structure
    def self.extract_structure(doc)
      elements = doc.xpath('//*').map(&:name).uniq.sort
      hierarchy = extract_hierarchy(doc.root) if doc.root

      {
        elements: elements,
        hierarchy: hierarchy,
        element_count: doc.xpath('//*').length
      }
    end

    # Extract element hierarchy
    def self.extract_hierarchy(element, depth = 0)
      return nil if depth > 10 # Prevent infinite recursion

      {
        name: element.name,
        children: element.children.select(&:element?).map { |child| extract_hierarchy(child, depth + 1) }
      }
    end

    # Extract attributes
    def self.extract_attributes(doc)
      attributes = {}

      doc.xpath('//*').each do |element|
        element.attributes.each do |name, attr|
          key = "#{element.name}@#{name}"
          attributes[key] ||= []
          attributes[key] << normalize_attribute_value(attr.value)
        end
      end

      attributes.transform_values(&:uniq)
    end

    # Extract text content
    def self.extract_content(doc)
      {
        text_nodes: doc.xpath('//text()').map(&:content).reject(&:empty?),
        cdata_sections: doc.xpath('//comment()').map(&:content)
      }
    end

    # Extract namespaces
    def self.extract_namespaces(doc)
      namespaces = {}

      doc.xpath('//*').each do |element|
        element.namespace_definitions.each do |ns|
          namespaces[ns.prefix || 'default'] = ns.href
        end
      end

      namespaces
    end

    # Extract style information
    def self.extract_styles(doc)
      styles = {}

      doc.xpath('//*[@style]').each do |element|
        style_attr = element['style']
        parsed_styles = parse_style_attribute(style_attr)
        styles[element.name] ||= []
        styles[element.name] << parsed_styles
      end

      styles
    end

    # Parse style attribute
    def self.parse_style_attribute(style_str)
      return {} if style_str.nil? || style_str.strip.empty?

      styles = {}
      style_str.split(';').each do |declaration|
        next if declaration.strip.empty?

        property, value = declaration.split(':', 2)
        next unless property && value

        styles[property.strip] = normalize_style_value(value.strip)
      end

      styles
    end

    # Compare structure
    def self.compare_structure(struct1, struct2)
      {
        elements_match: struct1[:elements] == struct2[:elements],
        hierarchy_match: compare_hierarchy(struct1[:hierarchy], struct2[:hierarchy]),
        element_count_match: struct1[:element_count] == struct2[:element_count]
      }
    end

    # Compare hierarchy
    def self.compare_hierarchy(hier1, hier2)
      return true if hier1.nil? && hier2.nil?
      return false if hier1.nil? || hier2.nil?

      return false unless hier1[:name] == hier2[:name]
      return false unless hier1[:children].length == hier2[:children].length

      hier1[:children].zip(hier2[:children]).all? do |child1, child2|
        compare_hierarchy(child1, child2)
      end
    end

    # Compare attributes
    def self.compare_attributes(attrs1, attrs2)
      all_keys = (attrs1.keys + attrs2.keys).uniq

      matches = all_keys.map do |key|
        values1 = attrs1[key] || []
        values2 = attrs2[key] || []
        values1.sort == values2.sort
      end

      {
        exact_match: matches.all?,
        partial_match_ratio: matches.count(true).to_f / matches.length,
        differing_attributes: all_keys.select.with_index { |_, i| !matches[i] }
      }
    end

    # Compare content
    def self.compare_content(content1, content2)
      {
        text_match: content1[:text_nodes].sort == content2[:text_nodes].sort,
        cdata_match: content1[:cdata_sections].sort == content2[:cdata_sections].sort
      }
    end

    # Compare namespaces
    def self.compare_namespaces(ns1, ns2)
      {
        exact_match: ns1 == ns2,
        common_namespaces: ns1.keys & ns2.keys,
        svg_conform_only: ns1.keys - ns2.keys,
        svgcheck_only: ns2.keys - ns1.keys
      }
    end

    # Compare styles
    def self.compare_styles(styles1, styles2)
      all_elements = (styles1.keys + styles2.keys).uniq

      element_comparisons = {}
      all_elements.each do |element|
        elem_styles1 = styles1[element] || []
        elem_styles2 = styles2[element] || []

        element_comparisons[element] = {
          count_match: elem_styles1.length == elem_styles2.length,
          semantic_match: compare_style_semantics(elem_styles1, elem_styles2)
        }
      end

      element_comparisons
    end

    # Compare style semantics
    def self.compare_style_semantics(styles1, styles2)
      # Flatten and normalize all styles
      flat1 = styles1.flat_map(&:to_a).to_h
      flat2 = styles2.flat_map(&:to_a).to_h

      # Compare normalized styles
      flat1 == flat2
    end

    # Calculate semantic equivalence
    def self.calculate_semantic_equivalence(features1, features2)
      structure_score = features1[:structure][:elements] == features2[:structure][:elements] ? 1.0 : 0.0
      namespace_score = features1[:namespaces] == features2[:namespaces] ? 1.0 : 0.0
      content_score = features1[:content] == features2[:content] ? 1.0 : 0.0

      # Weighted average
      (structure_score * 0.4 + namespace_score * 0.3 + content_score * 0.3).round(3)
    end

    # Utility methods for normalization
    def self.normalize_namespace(namespace)
      case namespace
      when /inkscape/i
        'inkscape'
      when /sodipodi/i
        'sodipodi'
      when /w3\.org.*svg/i
        'svg'
      else
        namespace
      end
    end

    def self.normalize_value(value)
      # Normalize common values for semantic comparison
      normalized = value.downcase.strip

      # Handle array-like values from svgcheck (e.g., "['malformed']" -> "malformed")
      normalized = ::Regexp.last_match(1) if normalized.match(/^\['([^']+)'\]$/)

      normalized
    end

    def self.normalize_color_value(color)
      # Normalize color values to handle different formats
      normalized = color.downcase.strip

      # Map common color equivalents
      case normalized
      when 'white', '#fff', '#ffffff', 'rgb(255,255,255)', 'rgb(255, 255, 255)', 'rgb(100%,100%,100%)', 'rgb(100%, 100%, 100%)'
        'white'
      when 'black', '#000', '#000000', 'rgb(0,0,0)', 'rgb(0, 0, 0)', 'rgb(0%,0%,0%)', 'rgb(0%, 0%, 0%)'
        'black'
      when 'red', '#f00', '#ff0000', 'rgb(255,0,0)', 'rgb(255, 0, 0)', 'rgb(100%,0%,0%)', 'rgb(100%, 0%, 0%)'
        'red'
      when 'green', '#0f0', '#00ff00', 'rgb(0,255,0)', 'rgb(0, 255, 0)', 'rgb(0%,100%,0%)', 'rgb(0%, 100%, 0%)'
        'green'
      when 'blue', '#00f', '#0000ff', 'rgb(0,0,255)', 'rgb(0, 0, 255)', 'rgb(0%,0%,100%)', 'rgb(0%, 0%, 100%)'
        'blue'
      when 'grey', 'gray'
        'grey'
      else
        # For hex colors, normalize to lowercase without spaces
        if normalized.match(/^#[0-9a-f]+$/i)
          normalized.downcase
        elsif normalized.match(/^rgb\s*\(/i)
          # Normalize RGB format by removing spaces
          normalized.gsub(/\s+/, '')
        else
          normalized
        end
      end
    end

    def self.normalize_message(message)
      # Extract key semantic components from message
      message.downcase.gsub(/['":]/, '').strip
    end

    def self.normalize_attribute_value(value)
      # Normalize attribute values for comparison
      value.strip.downcase
    end

    def self.normalize_style_value(value)
      # Normalize style values for comparison
      value.strip.downcase
    end
  end
end
