# frozen_string_literal: true

require_relative "lib/rails_psql_jsonb/version"

is_java = RUBY_PLATFORM == "java"

Gem::Specification.new do |spec|
  spec.name = "rails_psql_jsonb"
  spec.version = RailsPsqlJsonb::VERSION
  spec.authors = ["bubiche"]
  spec.email = ["bubiche95@gmail.com"]
  spec.platform = "java" if is_java

  spec.summary = "Rails Active Record helper to deal with jsonb columns in Postgresql."
  spec.description = "Helper for querying and updating Postgresql jsonb with ActiveRecord."
  spec.homepage = "https://github.com/bubiche/rails_psql_jsonb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/bubiche/rails_psql_jsonb"
  spec.metadata["changelog_uri"] = "https://github.com/bubiche/rails_psql_jsonb/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) || f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", ">= 6.1"
  spec.add_dependency "activesupport", ">= 6.1"
  if is_java
    spec.add_dependency "activerecord-jdbcpostgresql-adapter", ">= 61.0"
  else
    spec.add_dependency "pg", ">= 1.5.6"
  end

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
