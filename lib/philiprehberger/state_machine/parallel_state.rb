# frozen_string_literal: true

module Philiprehberger
  module StateMachine
    # Manages parallel (concurrent) substates that can be active simultaneously.
    class ParallelStateSet
      # @return [Array<Symbol>] the active substates
      attr_reader :active

      def initialize
        @active = []
      end

      # Activate a set of parallel substates.
      #
      # @param states [Array<Symbol>]
      def activate(states)
        @active = states.dup
      end

      # Deactivate all parallel substates.
      def deactivate
        @active = []
      end

      # Check if a specific substate is active.
      #
      # @param state [Symbol]
      # @return [Boolean]
      def active?(state)
        @active.include?(state)
      end

      # Check if any parallel substates are active.
      #
      # @return [Boolean]
      def any_active?
        !@active.empty?
      end
    end
  end
end
