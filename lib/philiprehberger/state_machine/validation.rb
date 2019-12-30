# frozen_string_literal: true

module Philiprehberger
  module StateMachine
    # Validates state machine definitions for unreachable states and other issues.
    module Validation
      # Find states that can never be reached from the initial state.
      #
      # @param definition [Definition] the state machine definition
      # @return [Array<Symbol>] unreachable states
      def self.unreachable_states(definition)
        reachable = reachable_states(definition)
        definition.all_states - reachable
      end

      # Find all states reachable from the initial state via BFS.
      #
      # @param definition [Definition] the state machine definition
      # @return [Array<Symbol>] reachable states
      def self.reachable_states(definition)
        visited = Set.new([definition.initial])
        queue = [definition.initial]

        until queue.empty?
          current = queue.shift
          targets = targets_from(definition, current)
          targets.each do |target|
            unless visited.include?(target)
              visited << target
              queue << target
            end
          end
        end

        visited.to_a
      end

      # Find all states that can transition to the given state.
      #
      # @param definition [Definition]
      # @param state [Symbol]
      # @return [Array<Symbol>]
      def self.predecessors(definition, state)
        result = []
        definition.events.each_value do |transitions|
          transitions.each do |t|
            next unless t.to == state

            Array(t.from).each do |from_state|
              result << from_state unless result.include?(from_state)
            end
          end
        end
        result
      end

      private_class_method def self.targets_from(definition, state)
        targets = []
        definition.events.each_value do |transitions|
          transitions.each do |t|
            targets << t.to if t.matches?(state)
          end
        end

        if definition.respond_to?(:auto_transitions)
          definition.auto_transitions.each do |at|
            targets << at.to if at.matches?(state)
          end
        end

        targets.uniq
      end
    end
  end
end
