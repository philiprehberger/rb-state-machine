# frozen_string_literal: true

module Philiprehberger
  module StateMachine
    # Tracks transition counts and time spent in each state.
    class Statistics
      # @param initial_state [Symbol]
      def initialize(initial_state)
        @transition_counts = Hash.new(0)
        @state_enter_times = { initial_state => Time.now }
        @time_in_states = Hash.new(0.0)
        @current_state = initial_state
        @total_transitions = 0
      end

      # Record a transition from one state to another.
      #
      # @param from [Symbol]
      # @param to [Symbol]
      def record_transition(from, to)
        now = Time.now
        key = :"#{from}_to_#{to}"
        @transition_counts[key] += 1
        @total_transitions += 1

        if @state_enter_times[from]
          @time_in_states[from] += now - @state_enter_times[from]
        end

        @state_enter_times[to] = now
        @current_state = to
      end

      # Total number of transitions.
      #
      # @return [Integer]
      def transition_count
        @total_transitions
      end

      # Time spent in a specific state (in seconds).
      # If currently in that state, includes elapsed time.
      #
      # @param state [Symbol]
      # @return [Float]
      def time_in_state(state)
        total = @time_in_states[state]
        if @current_state == state && @state_enter_times[state]
          total += Time.now - @state_enter_times[state]
        end
        total
      end

      # Return full statistics as a hash.
      #
      # @return [Hash]
      def to_h
        {
          total_transitions: @total_transitions,
          transition_counts: @transition_counts.dup,
          time_in_states: all_time_in_states
        }
      end

      private

      def all_time_in_states
        result = @time_in_states.dup
        if @state_enter_times[@current_state]
          result[@current_state] = (result[@current_state] || 0.0) +
                                   (Time.now - @state_enter_times[@current_state])
        end
        result
      end
    end
  end
end
