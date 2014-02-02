# Changelog

All notable changes to this gem will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
