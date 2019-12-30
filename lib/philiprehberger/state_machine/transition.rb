# frozen_string_literal: true

module Philiprehberger
  module StateMachine
    # Represents a single transition from one or more states to a target state.
    #
    # @attr_reader from [Symbol, Array<Symbol>] source state(s)
    # @attr_reader to [Symbol] target state
    # @attr_reader guard [Proc, nil] optional guard condition
    Transition = Struct.new(:from, :to, :guard, keyword_init: true) do
      # Check if this transition matches the given current state.
      #
      # @param current_state [Symbol]
      # @return [Boolean]
      def matches?(current_state)
        if from.is_a?(Array)
          from.include?(current_state)
        else
          from == current_state
        end
      end

      # Returns all source states as an array.
      #
      # @return [Array<Symbol>]
      def from_states
        Array(from)
      end
    end

    # Collects transitions for a single event via the DSL.
    class TransitionBuilder
      attr_reader :transitions, :parallel_definitions

      def initialize
        @transitions = []
        @parallel_definitions = {}
      end

      # Define a transition within an event block.
      #
      # @param from [Symbol, Array<Symbol>] source state(s)
      # @param to [Symbol] target state
      # @param guard [Proc, nil] optional guard lambda
      def transition(from:, to:, guard: nil)
        @transitions << Transition.new(from: from, to: to, guard: guard)
      end

      # Define parallel substates activated during this transition.
      #
      # @param states [Array<Symbol>] substates to activate concurrently
      def parallel_states(*states)
        key = @transitions.last&.to || :_default
        @parallel_definitions[key] = states.flatten
      end
    end
  end
end
