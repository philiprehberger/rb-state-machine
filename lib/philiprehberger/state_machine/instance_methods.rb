# frozen_string_literal: true

module Philiprehberger
  module StateMachine
    # Defines and mixes in instance methods on the host class.
    module InstanceMethods
      class << self
        # Define all state machine methods on the host class.
        #
        # @param klass [Class] the host class
        # @param definition [Definition] the state machine definition
        def define_methods(klass, definition)
          define_initializer(klass, definition)
          define_state_accessors(klass)
          define_event_methods(klass, definition)
          define_state_predicates(klass, definition)
          define_introspection(klass, definition)
        end

        private

        def define_initializer(klass, definition)
          initial = definition.initial
          initializer = Module.new do
            define_method(:initialize) do |*args, **kwargs, &block|
              @_sm_state = initial
              return unless method(:initialize).super_method

              if kwargs.empty?
                super(*args, &block)
              else
                super(*args, **kwargs, &block)
              end
            end
          end
          klass.prepend(initializer)
        end

        def define_state_accessors(klass)
          klass.define_method(:current_state) { @_sm_state }
          klass.send(:define_method, :_sm_set_state) { |state| @_sm_state = state }
          klass.send(:private, :_sm_set_state)
        end

        def define_event_methods(klass, definition)
          definition.events.each do |event_name, transitions|
            define_bang_method(klass, event_name, transitions, definition)
            define_safe_method(klass, event_name, transitions, definition)
            define_can_method(klass, event_name, transitions)
          end
        end

        def define_bang_method(klass, event_name, transitions, definition)
          klass.define_method(:"#{event_name}!") do
            transition = transitions.find { |t| t.matches?(current_state) }
            unless transition
              raise InvalidTransition,
                    "Cannot #{event_name} from #{current_state}"
            end

            if transition.guard && !instance_exec(&transition.guard)
              raise InvalidTransition,
                    "Guard condition failed for #{event_name} from #{current_state}"
            end

            from = current_state
            to = transition.to

            definition.callback_set.execute(type: :before, from: from, to: to, context: self)
            _sm_set_state(to)
            definition.callback_set.execute(type: :after, from: from, to: to, context: self)

            true
          end
        end

        def define_safe_method(klass, event_name, transitions, definition)
          klass.define_method(event_name) do
            transition = transitions.find { |t| t.matches?(current_state) }
            return false unless transition
            return false if transition.guard && !instance_exec(&transition.guard)

            from = current_state
            to = transition.to

            definition.callback_set.execute(type: :before, from: from, to: to, context: self)
            _sm_set_state(to)
            definition.callback_set.execute(type: :after, from: from, to: to, context: self)

            true
          end
        end

        def define_can_method(klass, event_name, transitions)
          klass.define_method(:"can_#{event_name}?") do
            transition = transitions.find { |t| t.matches?(current_state) }
            return false unless transition
            return false if transition.guard && !instance_exec(&transition.guard)

            true
          end
        end

        def define_state_predicates(klass, definition)
          definition.all_states.each do |state|
            klass.define_method(:"#{state}?") { current_state == state }
          end
        end

        def define_introspection(klass, definition)
          klass.define_method(:allowed_transitions) do
            definition.events.select do |_name, transitions|
              transition = transitions.find { |t| t.matches?(current_state) }
              next false unless transition
              next false if transition.guard && !instance_exec(&transition.guard)

              true
            end.keys
          end
        end
      end
    end
  end
end
