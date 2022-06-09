# frozen_string_literal: true

require_relative "lib/remotus/version"

Gem::Specification.new do |spec|
  spec.name          = "remotus"
  spec.version       = Remotus::VERSION
  spec.authors       = ["Matthew Newell"]
  spec.email         = ["matthewtnewell@gmail.com"]

  spec.summary       = "Ruby gem for connecting to remote systems seamlessly via WinRM or SSH."
  spec.description   = "Ruby gem for connecting to remote systems seamlessly via WinRM or SSH."
  spec.homepage      = "https://github.com/wheatevo/remotus"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.5.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/wheatevo/remotus"
  spec.metadata["documentation_uri"] = "https://wheatevo.github.io/remotus/"
  spec.metadata["changelog_uri"] = "https://github.com/wheatevo/remotus/blob/master/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Dependencies
  spec.add_dependency "connection_pool", "~> 2.2"
  spec.add_dependency "net-scp", "~> 3.0"
  spec.add_dependency "net-ssh", "~> 6.1"
  spec.add_dependency "winrm", "~> 2.3"
  spec.add_dependency "winrm-elevated", "~> 1.2"
  spec.add_dependency "winrm-fs", "~> 1.3"

  # Development dependencies
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 1.7"
  spec.add_development_dependency "rubocop-rake", "~> 0.5"
  spec.add_development_dependency "rubocop-rspec", "~> 2.2"
  spec.add_development_dependency "yard", "~> 0.9"
end
