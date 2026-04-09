# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.2] - 2026-04-09

### Fixed
- CI: split long gemspec summary line to satisfy RuboCop Layout/LineLength.

## [0.3.1] - 2026-04-08

### Changed
- Align gemspec summary with README description.

## [0.3.0] - 2026-04-01

### Added
- `on_enter(state, &block)` for state-scoped entry callbacks
- `on_exit(state, &block)` for state-scoped exit callbacks
- `#time_in_current_state` for elapsed time in current state

## [0.2.2] - 2026-03-31

### Added
- Add GitHub issue templates, dependabot config, and PR template

## [0.2.1] - 2026-03-31

### Changed
- Standardize README badges, support section, and license format

## [0.2.0] - 2026-03-28

### Added
- State history tracking with timestamps via `state_history` and `previous_state`
- Timed/automatic transitions with `auto_transition from:, to:, after:` DSL and `check_auto_transitions!`
- Parallel/concurrent substates with `parallel_states` DSL within events
- Transition statistics tracking via `transition_count`, `time_in_state`, and `transition_stats`
- DOT/GraphViz export for visual state diagrams via `MyClass.to_dot`
- Unreachable state detection and validation via `MyClass.unreachable_states`

## [0.1.2] - 2026-03-24

### Changed
- Expand test coverage to 55+ examples covering edge cases and error paths

## [0.1.1] - 2026-03-22

### Changed
- Expand test coverage to 38 examples

## [0.1.0] - 2026-03-21

### Added
- Initial release
- State machine DSL with `state_machine initial: :state` block syntax
- Event definitions with `event :name` and `transition from:, to:` DSL
- Guard conditions via `guard:` lambda on transitions
- Before and after transition callbacks with `to:` and `from:` filters
- State predicate methods (`state?`)
- Transition check methods (`can_event?`)
- Safe and bang event methods (`event` returns boolean, `event!` raises)
- `allowed_transitions` introspection method
- Works with any Ruby class, no framework dependency required
