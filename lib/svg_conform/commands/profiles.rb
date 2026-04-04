# frozen_string_literal: true

require "thor"
require "paint"
require "table_tennis"

module SvgConform
  module Commands
    # Profiles command for listing available validation profiles
    class Profiles
      class ProfilesError < Thor::Error; end

      def initialize(options)
        @options = options
        # Paint doesn't need initialization like Pastel
      end

      def execute
        profiles = load_available_profiles

        if @options[:verbose]
          display_detailed_profiles(profiles)
        else
          display_profile_list(profiles)
        end
      end

      private

      def load_available_profiles
        # Get all profile files
        profile_dir = File.join(File.dirname(__FILE__),
                                "../../../config/profiles")
        profile_files = Dir.glob(File.join(profile_dir, "*.yml"))

        profiles = {}

        profile_files.each do |file|
          name = File.basename(file, ".yml")
          begin
            profile = SvgConform::Profile.load_from_file(file)
            profiles[name] = profile
          rescue StandardError => e
            puts Paint["Warning: Could not load profile '#{name}': #{e.message}",
                       :yellow]
          end
        end

        profiles
      end

      def display_profile_list(profiles)
        puts Paint["Available SVG Profiles", :bold]
        puts "=" * 40
        puts

        if profiles.empty?
          puts Paint["No profiles found", :yellow]
          return
        end

        # Create table data - table_tennis handles its own formatting
        table_data = profiles.map do |name, profile|
          description = profile.description || "No description available"
          { profile: name, description: description }
        end

        # Use table_tennis with headers option
        table = TableTennis.new(table_data,
                                headers: { profile: "Profile",
                                           description: "Description" })
        puts table
        puts
        puts Paint["Use --verbose for detailed information about each profile",
                   :black]
      end

      def display_detailed_profiles(profiles)
        puts Paint["Detailed SVG Validation Profiles", :bold]
        puts "=" * 50
        puts

        profiles.each do |name, profile|
          puts Paint["Profile: #{name}", :bold]
          puts Paint["-" * 30, :black]

          puts "Description: #{profile.description || 'No description available'}"
          puts "Requirements: #{profile.requirement_count}"
          puts "Remediations: #{profile.remediation_count}"

          if profile.requirements&.any?
            puts "Requirement Details:"
            profile.requirements.each do |requirement|
              puts "  • #{requirement.class.name.split('::').last}"
              if requirement.respond_to?(:description) && requirement.description
                puts Paint["    #{requirement.description}",
                           :black]
              end
            end
          end

          if profile.remediations&.any?
            puts "Remediation Details:"
            profile.remediations.each do |remediation|
              puts "  • #{remediation.class.name.split('::').last}"
              if remediation.respond_to?(:description) && remediation.description
                puts Paint["    #{remediation.description}",
                           :black]
              end
            end
          end

          puts
        end
      end
    end
  end
end
