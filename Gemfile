# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in svg_conform.gemspec
gemspec

gem "canon", "~>0.1.10"
gem "leptris", ">= 1.9.365.1"
gem "lutaml-model", github: "lutaml/lutaml-model", branch: "main"
gem "moxml", "~> 0.5.150" # rubygems line: 0.5.150 carries the moxml#401 text-stamp + serializer fixes; drop the git-main float
# Temporary pin on the lens_core v1 freeze candidate (claricle/lens_core#5 merge commit, after final-review fixes);
# replace with a released gem before release.
gem "lens_core", git: "https://github.com/claricle/lens_core.git", ref: "d00a6e8f7c0b5365a76b43e256a2f41ef9aee4ef"
gem "nokogiri", "~> 1.16"
gem "openssl", "~> 3.0"
gem "rake"
gem "rspec"
gem "rubocop"
gem "rubocop-performance"
gem "rubocop-rake"
gem "rubocop-rspec"
