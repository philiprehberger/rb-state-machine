# frozen_string_literal: true

require 'set'
require_relative 'state_machine/version'
require_relative 'state_machine/transition'
require_relative 'state_machine/callbacks'
require_relative 'state_machine/definition'
require_relative 'state_machine/instance_methods'
require_relative 'state_machine/history'
require_relative 'state_machine/auto_transition'
require_relative 'state_machine/parallel_state'
require_relative 'state_machine/statistics'
require_relative 'state_machine/graph_export'
require_relative 'state_machine/validation'

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

      # Generate a DOT/GraphViz string for this state machine.
      #
      # @param name [String] optional graph name
      # @return [String] DOT format string
      def to_dot(name: self.name || 'StateMachine')
        raise Error, 'No state machine defined' unless @_sm_definition

        GraphExport.to_dot(@_sm_definition, name: name)
      end

      # Find states that cannot be reached from the initial state.
      #
      # @return [Array<Symbol>] unreachable states
      def unreachable_states
        raise Error, 'No state machine defined' unless @_sm_definition

        Validation.unreachable_states(@_sm_definition)
      end
    end
  end
end
