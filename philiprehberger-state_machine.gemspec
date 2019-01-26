# frozen_string_literal: true

require_relative 'lib/philiprehberger/state_machine/version'

Gem::Specification.new do |spec|
  spec.name          = 'philiprehberger-state_machine'
  spec.version       = Philiprehberger::StateMachine::VERSION
  spec.authors       = ['Philip Rehberger']
  spec.email         = ['me@philiprehberger.com']

  spec.summary       = 'Lightweight state machine DSL with transitions, guards, and callbacks'
  spec.description   = 'A minimal state machine for Ruby objects. Define states, events, ' \
                       'transitions, guard conditions, and callbacks with a clean DSL. ' \
                       'Works with any Ruby class — no framework dependency required.'
  spec.homepage      = 'https://github.com/philiprehberger/rb-state-machine'
  spec.license       = 'MIT'

  spec.required_ruby_version = '>= 3.1.0'

  spec.metadata['homepage_uri']          = spec.homepage
  spec.metadata['source_code_uri']       = spec.homepage
  spec.metadata['changelog_uri']         = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata['bug_tracker_uri']       = "#{spec.homepage}/issues"
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files         = Dir['lib/**/*.rb', 'LICENSE', 'README.md', 'CHANGELOG.md']
  spec.require_paths = ['lib']
end
