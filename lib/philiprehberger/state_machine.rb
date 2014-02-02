# frozen_string_literal: true

require_relative "state_machine/version"
require_relative "state_machine/transition"
require_relative "state_machine/callbacks"
require_relative "state_machine/definition"
require_relative "state_machine/instance_methods"

module Philiprehberger
  module StateMachine
    class Error < StandardError; end
    class InvalidTransition < Error; end

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      # Define a state machine on the class.
      #
      # @param initial [Symbol] the initial state
      # @yield block evaluated via Definition DSL
      def state_machine(initial:, &block)
        definition = Definition.new(initial: initial)
        definition.instance_eval(&block)

        @_sm_definition = definition

        InstanceMethods.define_methods(self, definition)
      end

      # @return [Definition] the state machine definition
      def _sm_definition
        @_sm_definition
      end
    end
  end
end
