# frozen_string_literal: true

module SvgConform
  # Namespace for external SVG conformance checkers
  # This allows for multiple external checker integrations while keeping them separate
  module ExternalCheckers
    autoload :Svgcheck, "svg_conform/external_checkers/svgcheck"

    # Base class for external checker integrations
    class BaseChecker
      attr_reader :name, :version

      def initialize(name:, version: nil)
        @name = name
        @version = version
      end

      # Generate outputs for a given file - to be implemented by subclasses
      def generate_outputs(input_file, mode: :both)
        raise NotImplementedError, "Subclasses must implement generate_outputs"
      end

      # Parse checker output into a ConformanceReport - to be implemented by subclasses
      def parse_output(output_content, error_content = nil)
        raise NotImplementedError, "Subclasses must implement parse_output"
      end

      # Check if the checker is available on the system
      def available?
        raise NotImplementedError, "Subclasses must implement available?"
      end
    end
  end
end
