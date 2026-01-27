# frozen_string_literal: true

require "svg_conform"
require "canon"

# Load shared examples
Dir[File.expand_path("support/**/*.rb", __dir__)].each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Clear class-level caches before each test to prevent pollution
  config.before do
    # Clear AllowedElementsRequirement configuration cache
    if defined?(SvgConform::Requirements::AllowedElementsRequirement)
      SvgConform::Requirements::AllowedElementsRequirement.configuration_validation_cache.clear
    end

    # Clear ProfileCompiler compile cache
    if defined?(SvgConform::ProfileCompiler)
      SvgConform::ProfileCompiler.compile_cache.clear
    end

    # Clear Profiles module cache
    if defined?(SvgConform::Profiles)
      SvgConform::Profiles.clear_cache!
    end
  end
end
