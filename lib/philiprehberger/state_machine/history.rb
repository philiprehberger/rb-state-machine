# frozen_string_literal: true

module Philiprehberger
  module StateMachine
    # Tracks state history with timestamps.
    class History
      Entry = Struct.new(:state, :entered_at, keyword_init: true)

      attr_reader :max_size

      # @param initial_state [Symbol] the starting state
      # @param max_size [Integer] maximum number of entries to retain
      def initialize(initial_state, max_size: 100)
        @max_size = max_size
        @entries = [Entry.new(state: initial_state, entered_at: Time.now)]
      end

      # Record a new state entry.
      #
      # @param state [Symbol]
      def record(state)
        @entries << Entry.new(state: state, entered_at: Time.now)
        @entries.shift if @entries.size > @max_size
      end

      # Return all history entries as an array of hashes.
      #
      # @return [Array<Hash>]
      def entries
        @entries.map { |e| { state: e.state, entered_at: e.entered_at } }
      end

      # Return the previous state (before the current one).
      #
      # @return [Symbol, nil]
      def previous_state
        return nil if @entries.size < 2

        @entries[-2].state
      end

      # Number of recorded entries.
      #
      # @return [Integer]
      def size
        @entries.size
      end
    end
  end
end
