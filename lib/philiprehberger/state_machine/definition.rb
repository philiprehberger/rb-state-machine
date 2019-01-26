# frozen_string_literal: true

module Philiprehberger
  module StateMachine
    # DSL class used inside the `state_machine` block to define events,
    # transitions, and callbacks.
    class Definition
      attr_reader :initial, :events, :callback_set

      # @param initial [Symbol] the initial state
      def initialize(initial:)
        @initial = initial
        @events = {}
        @callback_set = CallbackSet.new
      end

      # Define an event with transitions.
      #
      # @param name [Symbol] event name
      # @yield block evaluated via TransitionBuilder
      def event(name, &)
        builder = TransitionBuilder.new
        builder.instance_eval(&)
        @events[name] = builder.transitions
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
        states.uniq
      end
    end
  end
end
