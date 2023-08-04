# philiprehberger-state_machine

[![Tests](https://github.com/philiprehberger/rb-state-machine/actions/workflows/ci.yml/badge.svg)](https://github.com/philiprehberger/rb-state-machine/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/philiprehberger-state_machine.svg)](https://rubygems.org/gems/philiprehberger-state_machine)
[![Last updated](https://img.shields.io/github/last-commit/philiprehberger/rb-state-machine)](https://github.com/philiprehberger/rb-state-machine/commits/main)

Lightweight state machine DSL with transitions, guards, callbacks, history tracking, auto-transitions, parallel states, statistics, and graph export.

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

### Basic State Machine

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

### State History

Track previous states with timestamps:

```ruby
order = Order.new
order.pay!
order.state_history
# => [{state: :pending, entered_at: <Time>}, {state: :paid, entered_at: <Time>}]
order.previous_state  # => :pending
```

### Timed/Automatic Transitions

Define transitions that trigger automatically after a time period:

```ruby
class Session
  include Philiprehberger::StateMachine

  state_machine initial: :active do
    event :refresh do
      transition from: :active, to: :active
    end

    auto_transition from: :active, to: :expired, after: 1800
  end
end

session = Session.new
# Later, check if any auto-transitions should fire:
session.check_auto_transitions!  # => true if expired, false otherwise
```

### Parallel States

Activate concurrent substates during a transition:

```ruby
class Upload
  include Philiprehberger::StateMachine

  state_machine initial: :idle do
    event :start do
      transition from: :idle, to: :processing
      parallel_states :uploading, :validating
    end

    event :finish do
      transition from: :processing, to: :done
    end
  end
end

upload = Upload.new
upload.start!
upload.parallel_states              # => [:uploading, :validating]
upload.parallel_state_active?(:uploading)  # => true
upload.finish!
upload.parallel_states              # => []
```

### Transition Statistics

Track transition counts and time spent in each state:

```ruby
order = Order.new
order.pay!
order.transition_count          # => 1
order.time_in_state(:pending)   # => 0.003 (seconds)
order.transition_stats
# => {total_transitions: 1, transition_counts: {pending_to_paid: 1}, time_in_states: {...}}
```

### State Lifecycle Hooks

Fire callbacks when entering or leaving a specific state, regardless of which event triggered the transition:

```ruby
state_machine initial: :idle do
  on_enter(:active) { |obj| obj.log("Entered active") }
  on_exit(:idle) { |obj| obj.log("Left idle") }

  event :start do
    transition from: :idle, to: :active
  end
end
```

### Time in Current State

```ruby
obj.time_in_current_state  # => 12.5 (seconds)
```

### DOT/GraphViz Export

Generate a visual state diagram in DOT format:

```ruby
puts Order.to_dot
# digraph Order {
#   rankdir=LR;
#   __start__ [shape=point, width=0.2];
#   __start__ -> pending;
#   pending [shape=ellipse];
#   ...
# }
```

Render with GraphViz: `dot -Tpng -o states.png`

### Unreachable State Detection

Validate that all states can be reached from the initial state:

```ruby
Order.unreachable_states  # => [] (all reachable)
```

## API

| Method | Description |
|--------|-------------|
| `state_machine(initial:, &block)` | Define a state machine on the class with an initial state |
| `event(name, &block)` | Define an event inside the state machine block |
| `transition(from:, to:, guard: nil)` | Define a transition inside an event block |
| `parallel_states(*states)` | Activate concurrent substates during a transition |
| `auto_transition(from:, to:, after:, guard: nil)` | Define a timed automatic transition |
| `before_transition(to: nil, from: nil, &block)` | Register a callback that fires before a transition |
| `after_transition(to: nil, from: nil, &block)` | Register a callback that fires after a transition |
| `#current_state` | Returns the current state as a symbol |
| `#can_X?` | Returns true if event X can fire from the current state (including guards) |
| `#allowed_transitions` | Returns an array of event names that can fire from the current state |
| `#X!` | Fire event X or raise `InvalidTransition` |
| `#X` | Fire event X, returns true on success, false on failure |
| `#X?` | Returns true if current state is X |
| `#state_history` | Returns array of `{state:, entered_at:}` hashes |
| `#previous_state` | Returns the state before the current one, or nil |
| `#transition_count` | Returns total number of transitions performed |
| `#time_in_state(state)` | Returns seconds spent in the given state |
| `#transition_stats` | Returns hash with counts and timing for all transitions |
| `#parallel_states` | Returns array of currently active parallel substates |
| `#parallel_state_active?(state)` | Returns true if the given substate is active |
| `on_enter(state, &block)` | Callback fired when entering a state |
| `on_exit(state, &block)` | Callback fired when leaving a state |
| `#time_in_current_state` | Seconds spent in current state |
| `#check_auto_transitions!` | Fires any pending auto-transitions, returns true if one fired |
| `.to_dot(name:)` | Generates DOT/GraphViz string for the state machine |
| `.unreachable_states` | Returns array of states unreachable from initial |

## Development

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## Support

If you find this project useful:

⭐ [Star the repo](https://github.com/philiprehberger/rb-state-machine)

🐛 [Report issues](https://github.com/philiprehberger/rb-state-machine/issues?q=is%3Aissue+is%3Aopen+label%3Abug)

💡 [Suggest features](https://github.com/philiprehberger/rb-state-machine/issues?q=is%3Aissue+is%3Aopen+label%3Aenhancement)

❤️ [Sponsor development](https://github.com/sponsors/philiprehberger)

🌐 [All Open Source Projects](https://philiprehberger.com/open-source-packages)

💻 [GitHub Profile](https://github.com/philiprehberger)

🔗 [LinkedIn Profile](https://www.linkedin.com/in/philiprehberger)

## License

[MIT](LICENSE)
