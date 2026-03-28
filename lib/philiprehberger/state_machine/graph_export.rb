# frozen_string_literal: true

module Philiprehberger
  module StateMachine
    # Generates DOT/GraphViz output for state machine visualization.
    module GraphExport
      # Generate a DOT-format string representing the state machine.
      #
      # @param definition [Definition] the state machine definition
      # @param name [String] graph name
      # @return [String] DOT format string
      def self.to_dot(definition, name: 'StateMachine')
        lines = []
        lines << "digraph #{name} {"
        lines << '  rankdir=LR;'
        lines << ''

        # Initial state indicator
        lines << '  __start__ [shape=point, width=0.2];'
        lines << "  __start__ -> #{definition.initial};"
        lines << ''

        # State nodes
        definition.all_states.each do |state|
          lines << "  #{state} [shape=ellipse];"
        end
        lines << ''

        # Transitions
        definition.events.each do |event_name, transitions|
          transitions.each do |t|
            Array(t.from).each do |from_state|
              guard_label = t.guard ? ' [guarded]' : ''
              lines << "  #{from_state} -> #{t.to} [label=\"#{event_name}#{guard_label}\"];"
            end
          end
        end

        # Auto-transitions
        if definition.respond_to?(:auto_transitions) && definition.auto_transitions.any?
          definition.auto_transitions.each do |at|
            Array(at.from).each do |from_state|
              lines << "  #{from_state} -> #{at.to} [label=\"auto(#{at.after}s)\", style=dashed];"
            end
          end
        end

        lines << '}'
        lines.join("\n")
      end
    end
  end
end
