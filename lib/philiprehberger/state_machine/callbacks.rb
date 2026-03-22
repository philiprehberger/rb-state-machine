# frozen_string_literal: true

module Philiprehberger
  module StateMachine
    # Represents a single callback with optional state filters.
    #
    # @attr_reader type [:before, :after] callback timing
    # @attr_reader block [Proc] the callback to execute
    # @attr_reader conditions [Hash] optional :from and :to filters
    Callback = Struct.new(:type, :block, :conditions, keyword_init: true)

    # Stores and filters callbacks for state transitions.
    class CallbackSet
      def initialize
        @callbacks = []
      end

      # Register a callback.
      #
      # @param type [:before, :after]
      # @param conditions [Hash] optional :from and :to state filters
      # @param block [Proc]
      def add(type:, conditions: {}, &block)
        @callbacks << Callback.new(type: type, block: block, conditions: conditions)
      end

      # Execute all matching callbacks for the given transition.
      #
      # @param type [:before, :after]
      # @param from [Symbol] source state
      # @param to [Symbol] target state
      # @param context [Object] the object to pass to the callback
      def execute(type:, from:, to:, context:)
        matching(type: type, from: from, to: to).each do |callback|
          callback.block.call(context)
        end
      end

      private

      def matching(type:, from:, to:)
        @callbacks.select do |cb|
          next false unless cb.type == type

          matches_condition?(cb.conditions[:from], from) &&
            matches_condition?(cb.conditions[:to], to)
        end
      end

      def matches_condition?(condition, state)
        return true if condition.nil?

        if condition.is_a?(Array)
          condition.include?(state)
        else
          condition == state
        end
      end
    end
  end
end
