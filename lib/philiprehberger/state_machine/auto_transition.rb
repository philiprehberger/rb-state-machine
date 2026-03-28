# frozen_string_literal: true

module Philiprehberger
  module StateMachine
    # Represents a timed automatic transition.
    AutoTransition = Struct.new(:from, :to, :after, :guard, keyword_init: true) do
      # Check if this auto-transition applies to the given state.
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
    end
  end
end
