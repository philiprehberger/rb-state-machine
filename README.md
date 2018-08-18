# philiprehberger-state_machine

[![Tests](https://github.com/philiprehberger/rb-state-machine/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-state-machine/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-state_machine.svg)](https://rubygems.org/gems/philiprehberger-state_machine)
[![License](https://img.shields.io/github/license/philiprehberger/rb-state-machine)](LICENSE)
[![Sponsor](https://img.shields.io/badge/sponsor-GitHub%20Sponsors-ec6cb9)](https://github.com/sponsors/philiprehberger)

Lightweight state machine DSL with transitions, guards, and callbacks

## Requirements

- Ruby >= 3.1

## Installation

Add to your Gemfile:

```ruby
gem "philiprehberger-state_machine"
```

Or install directly:

```bash
gem install philiprehberger-state_machine
```

## Usage

```ruby
require "philiprehberger/state_machine"

class Order
  include Philiprehberger::StateMachine

  state_machine initial: :pending do
    event :pay do
      transition from: :pending, to: :paid
    end

    event :ship do
      transition from: :paid, to: :shipped
    end

    event :deliver do
      transition from: :shipped, to: :delivered
    end
  end
end

order = Order.new
order.current_state  # => :pending
order.pay!
order.current_state  # => :paid
```

### Guards

Attach a guard lambda to conditionally block transitions:

```ruby
class Order
  include Philiprehberger::StateMachine

  attr_accessor :tracking_number

  state_machine initial: :pending do
    event :pay do
      transition from: :pending, to: :paid
    end

    event :ship do
      transition from: :paid, to: :shipped, guard: -> { !tracking_number.nil? }
    end
  end
end

order = Order.new
order.pay!
order.ship              # => false (no tracking number)
order.tracking_number = "TRACK123"
order.ship!             # => transitions to :shipped
```

### Callbacks

Register before and after callbacks with optional state filters:

```ruby
class Order
  include Philiprehberger::StateMachine

  state_machine initial: :pending do
    event :pay do
      transition from: :pending, to: :paid
    end

    before_transition to: :paid do |order|
      puts "About to mark order as paid"
    end

    after_transition to: :paid do |order|
      puts "Order is now paid"
    end
  end
end
```

### Introspection

Query the state machine at runtime:

```ruby
order = Order.new

order.pending?            # => true
order.paid?               # => false
order.can_pay?            # => true
order.can_ship?           # => false
order.allowed_transitions # => [:pay]
```

## API

| Method | Description |
|--------|-------------|
| `state_machine(initial:, &block)` | Define a state machine on the class with an initial state |
| `event(name, &block)` | Define an event inside the state machine block |
| `transition(from:, to:, guard: nil)` | Define a transition inside an event block |
| `before_transition(to: nil, from: nil, &block)` | Register a callback that fires before a transition |
| `after_transition(to: nil, from: nil, &block)` | Register a callback that fires after a transition |
| `#current_state` | Returns the current state as a symbol |
| `#can_X?` | Returns true if event X can fire from the current state (including guards) |
| `#allowed_transitions` | Returns an array of event names that can fire from the current state |
| `#X!` | Fire event X or raise `InvalidTransition` |
| `#X` | Fire event X, returns true on success, false on failure |
| `#X?` | Returns true if current state is X |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## License

MIT
