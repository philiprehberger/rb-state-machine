# frozen_string_literal: true

module Philiprehberger
  module StateMachine
    # DSL class used inside the `state_machine` block to define events,
    # transitions, and callbacks.
    class Definition
      attr_reader :initial, :events, :callback_set, :auto_transitions, :parallel_state_definitions, :final_states

      # @param initial [Symbol] the initial state
      def initialize(initial:)
        @initial = initial
        @events = {}
        @callback_set = CallbackSet.new
        @auto_transitions = []
        @parallel_state_definitions = {}
        @final_states = []
      end

      # Declare a state, optionally marking it as final/terminal.
      #
      # Calling `state :name` without options is a no-op used for documentation
      # and introspection. Passing `final: true` marks the state as terminal,
      # enabling the `#final?` / `#terminal?` predicates on instances.
      #
      # @param name [Symbol] the state name
      # @param final [Boolean] whether this state is terminal
      def state(name, final: false)
        @final_states << name if final && !@final_states.include?(name)
        name
      end

      # Returns true if the given state name is declared final.
      #
      # @param name [Symbol] the state name
      # @return [Boolean]
      def final_state?(name)
        @final_states.include?(name)
      end

      # Define an event with transitions.
      #
      # @param name [Symbol] event name
      # @yield block evaluated via TransitionBuilder
      def event(name, &)
        builder = TransitionBuilder.new
        builder.instance_eval(&)
        @events[name] = builder.transitions

        # Store parallel state definitions if any
        @parallel_state_definitions[name] = builder.parallel_definitions if builder.parallel_definitions.any?
      end

      # Register a before_transition callback.
      #
      # @param opts [Hash] optional :from and :to state filters
      # @yield [Object] block receives the host object
      def before_transition(opts = {}, &)
        @callback_set.add(type: :before, conditions: opts, &)
      end

      # Register an after_transition callback.
      #
      # @param opts [Hash] optional :from and :to state filters
      # @yield [Object] block receives the host object
      def after_transition(opts = {}, &)
        @callback_set.add(type: :after, conditions: opts, &)
      end

      # Define a timed automatic transition.
      #
      # @param from [Symbol, Array<Symbol>] source state(s)
      # @param to [Symbol] target state
      # @param after [Numeric] seconds to wait before auto-transitioning
      # @param guard [Proc, nil] optional guard condition
      def auto_transition(from:, to:, after:, guard: nil)
        @auto_transitions << AutoTransition.new(from: from, to: to, after: after, guard: guard)
      end

      def on_enter(state, &block)
        (@enter_hooks ||= {})[state] = block
      end

      def on_exit(state, &block)
        (@exit_hooks ||= {})[state] = block
      end

      def enter_hooks
        @enter_hooks || {}
      end

      def exit_hooks
        @exit_hooks || {}
      end

      # Returns all unique states referenced in the definition.
      #
      # @return [Array<Symbol>]
      def all_states
        states = [initial]
        events.each_value do |transitions|
          transitions.each do |t|
            states.concat(Array(t.from))
            states << t.to
          end
        end
        auto_transitions.each do |at|
          states.concat(Array(at.from))
          states << at.to
        end
        states.concat(@final_states)
        states.uniq
      end
    end
  end
end
