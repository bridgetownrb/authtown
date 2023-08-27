# frozen_string_literal: true

require_relative "lib/authtown/version"

Gem::Specification.new do |spec|
  spec.name          = "authtown"
  spec.version       = Authtown::VERSION
  spec.author        = "Bridgetown Team"
  spec.email         = "maintainers@bridgetownrb.com"
  spec.summary       = "Rodauth integration for Bridgetown"
  spec.homepage      = "https://github.com/bridgetownrb/authtown"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r!^(test|script|spec|features|frontend)/!) }
  spec.test_files    = spec.files.grep(%r!^test/!)
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 3.1"

  spec.add_dependency "bridgetown", ">= 1.3.0", "< 2.0"
  spec.add_dependency "rodauth", ">= 2.30"
  spec.add_dependency "bcrypt", ">= 3.1"
  spec.add_dependency "mail", ">= 2.8"

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake", ">= 13.0"
  spec.add_development_dependency "rubocop-bridgetown", "~> 0.3"
end
