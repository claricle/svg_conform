# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in svg_conform.gemspec
gemspec

gem "canon", "~>0.1.10"
gem "lutaml-model", github: "lutaml/lutaml-model", branch: "main"
gem "moxml", "~> 0.5.150" # rubygems line: 0.5.150 carries the moxml#401 text-stamp + serializer fixes; drop the git-main float
# Temporary pin on the open lens_core PR branch (claricle/lens_core#1);
# repin to the merged main SHA, then a released gem, before release.
gem "lens_core", git: "https://github.com/claricle/lens_core.git", branch: "feat/lens-core-v1"
gem "leptris", ">= 1.9.365.1"
gem "openssl", "~> 3.0"
gem "rake"
gem "rspec"
gem "rubocop"
gem "rubocop-performance"
gem "rubocop-rake"
gem "rubocop-rspec"
