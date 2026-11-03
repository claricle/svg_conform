# frozen_string_literal: true

require "yeptris/psych"

module SvgConform
  # YAML operations through Yeptris without installing its global drop-in.
  module YamlIO
    def self.load_file(...)
      Yeptris::Psych.load_file(...)
    end

    def self.safe_load_file(...)
      Yeptris::Psych.safe_load_file(...)
    end

    def self.dump(...)
      Yeptris::Psych.dump(...)
    end
  end
end
