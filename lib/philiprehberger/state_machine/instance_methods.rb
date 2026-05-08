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
          define_history_methods(klass)
          define_statistics_methods(klass)
          define_parallel_state_methods(klass)
          define_auto_transition_methods(klass, definition)
          define_event_methods(klass, definition)
          define_state_predicates(klass, definition)
          define_final_state_predicates(klass, definition)
          define_introspection(klass, definition)
        end

        private

        def define_initializer(klass, definition)
          initial = definition.initial
          initializer = Module.new do
            define_method(:initialize) do |*args, **kwargs, &block|
              @_sm_state = initial
              @_sm_history = History.new(initial)
              @_sm_statistics = Statistics.new(initial)
              @_sm_parallel_states = ParallelStateSet.new
              @_sm_state_entered_at = Time.now
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
          klass.define_method(:time_in_current_state) { Time.now - @_sm_state_entered_at }
          klass.send(:define_method, :_sm_set_state) do |state|
            @_sm_state = state
            @_sm_state_entered_at = Time.now
          end
          klass.send(:private, :_sm_set_state)

          klass.send(:define_method, :_sm_invoke_hook) do |hook, payload|
            return unless hook

            if [0, 1].include?(hook.arity)
              hook.call(self)
            else
              hook.call(self, payload)
            end
          end
          klass.send(:private, :_sm_invoke_hook)
        end

        def define_history_methods(klass)
          klass.define_method(:state_history) { @_sm_history.entries }
          klass.define_method(:previous_state) { @_sm_history.previous_state }
        end

        def define_statistics_methods(klass)
          klass.define_method(:transition_count) { @_sm_statistics.transition_count }
          klass.define_method(:time_in_state) { |state| @_sm_statistics.time_in_state(state) }
          klass.define_method(:transition_stats) { @_sm_statistics.to_h }
        end

        def define_parallel_state_methods(klass)
          klass.define_method(:parallel_states) { @_sm_parallel_states.active }
          klass.define_method(:parallel_state_active?) { |state| @_sm_parallel_states.active?(state) }
        end

        def define_auto_transition_methods(klass, definition)
          klass.define_method(:check_auto_transitions!) do
            now = Time.now
            definition.auto_transitions.each do |at|
              next unless at.matches?(current_state)
              next if at.guard && !instance_exec(&at.guard)

              elapsed = now - @_sm_state_entered_at
              next unless elapsed >= at.after

              from = current_state
              to = at.to

              definition.callback_set.execute(type: :before, from: from, to: to, context: self)
              @_sm_history.record(to)
              @_sm_statistics.record_transition(from, to)
              @_sm_parallel_states.deactivate
              _sm_set_state(to)
              definition.callback_set.execute(type: :after, from: from, to: to, context: self)

              return true
            end
            false
          end
        end

        def define_event_methods(klass, definition)
          definition.events.each do |event_name, transitions|
            parallel_defs = definition.parallel_state_definitions[event_name] || {}
            define_bang_method(klass, event_name, transitions, definition, parallel_defs)
            define_safe_method(klass, event_name, transitions, definition, parallel_defs)
            define_can_method(klass, event_name, transitions)
          end
        end

        def define_bang_method(klass, event_name, transitions, definition, parallel_defs)
          klass.define_method(:"#{event_name}!") do |**payload|
            transition = transitions.find { |t| t.matches?(current_state) }
            unless transition
              raise InvalidTransition,
                    "Cannot #{event_name} from #{current_state}"
            end

            if transition.guard
              guard_result = if transition.guard.arity.zero?
                               instance_exec(&transition.guard)
                             else
                               instance_exec(**payload, &transition.guard)
                             end
              unless guard_result
                raise InvalidTransition,
                      "Guard condition failed for #{event_name} from #{current_state}"
              end
            end

            from = current_state
            to = transition.to

            definition.callback_set.execute(type: :before, from: from, to: to, context: self, payload: payload)
            _sm_invoke_hook(definition.exit_hooks[from], payload)
            @_sm_history.record(to)
            @_sm_statistics.record_transition(from, to)

            # Handle parallel states
            if parallel_defs[to]
              @_sm_parallel_states.activate(parallel_defs[to])
            else
              @_sm_parallel_states.deactivate
            end

            _sm_set_state(to)
            _sm_invoke_hook(definition.enter_hooks[to], payload)
            definition.callback_set.execute(type: :after, from: from, to: to, context: self, payload: payload)

            true
          end
        end

        def define_safe_method(klass, event_name, transitions, definition, parallel_defs)
          klass.define_method(event_name) do |**payload|
            transition = transitions.find { |t| t.matches?(current_state) }
            return false unless transition

            if transition.guard
              guard_result = if transition.guard.arity.zero?
                               instance_exec(&transition.guard)
                             else
                               instance_exec(**payload, &transition.guard)
                             end
              return false unless guard_result
            end

            from = current_state
            to = transition.to

            definition.callback_set.execute(type: :before, from: from, to: to, context: self, payload: payload)
            _sm_invoke_hook(definition.exit_hooks[from], payload)
            @_sm_history.record(to)
            @_sm_statistics.record_transition(from, to)

            # Handle parallel states
            if parallel_defs[to]
              @_sm_parallel_states.activate(parallel_defs[to])
            else
              @_sm_parallel_states.deactivate
            end

            _sm_set_state(to)
            _sm_invoke_hook(definition.enter_hooks[to], payload)
            definition.callback_set.execute(type: :after, from: from, to: to, context: self, payload: payload)

            true
          end
        end

        def define_can_method(klass, event_name, transitions)
          klass.define_method(:"can_#{event_name}?") do |**payload|
            transition = transitions.find { |t| t.matches?(current_state) }
            return false unless transition

            if transition.guard
              guard_result = if transition.guard.arity.zero?
                               instance_exec(&transition.guard)
                             else
                               instance_exec(**payload, &transition.guard)
                             end
              return false unless guard_result
            end

            true
          end
        end

        def define_state_predicates(klass, definition)
          definition.all_states.each do |state|
            klass.define_method(:"#{state}?") { current_state == state }
          end
        end

        def define_final_state_predicates(klass, definition)
          klass.define_method(:final?) { definition.final_state?(current_state) }
          klass.define_method(:terminal?) { definition.final_state?(current_state) }

          # Returns true if the instance has no allowed transitions AND the current
          # state is not marked `final: true`. Distinguishes a dead-end state (no way
          # out, but not declared terminal) from a legitimate final state.
          #
          # @return [Boolean] true when stuck with no outgoing transitions, false otherwise
          klass.define_method(:stuck?) { allowed_transitions.empty? && !final? }
        end

        def define_introspection(klass, definition)
          klass.define_method(:allowed_transitions) do |**payload|
            definition.events.select do |_name, transitions|
              transition = transitions.find { |t| t.matches?(current_state) }
              next false unless transition

              if transition.guard
                guard_result = if transition.guard.arity.zero?
                                 instance_exec(&transition.guard)
                               else
                                 instance_exec(**payload, &transition.guard)
                               end
                next false unless guard_result
              end

              true
            end.keys
          end

          # Whether any currently-fireable event would land the machine in `state`.
          # Honours guards (a guarded-out transition reports false). Useful for UI
          # gating without hand-rolling the per-event lookup.
          #
          # @param state [Symbol] the candidate target state
          # @param payload [Hash] keyword payload forwarded to guards that accept it
          # @return [Boolean]
          # @raise [ArgumentError] if `state` is not declared on the machine
          klass.define_method(:can_transition_to?) do |state, **payload|
            unless definition.all_states.include?(state)
              raise ArgumentError, "Unknown state: #{state.inspect}"
            end

            definition.events.any? do |_name, transitions|
              transition = transitions.find { |t| t.matches?(current_state) && t.to == state }
              next false unless transition

              if transition.guard
                guard_result = if transition.guard.arity.zero?
                                 instance_exec(&transition.guard)
                               else
                                 instance_exec(**payload, &transition.guard)
                               end
                next false unless guard_result
              end

              true
            end
          end
        end
      end
    end
  end
end
