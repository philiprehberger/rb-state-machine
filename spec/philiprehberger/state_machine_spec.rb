# frozen_string_literal: true

require 'spec_helper'

class TestOrder
  include Philiprehberger::StateMachine

  attr_accessor :tracking_number, :callback_log

  def initialize
    @callback_log = []
  end

  state_machine initial: :pending do
    event :pay do
      transition from: :pending, to: :paid
    end

    event :ship do
      transition from: :paid, to: :shipped, guard: -> { !tracking_number.nil? }
    end

    event :deliver do
      transition from: :shipped, to: :delivered
    end

    event :cancel do
      transition from: %i[pending paid], to: :cancelled
    end

    before_transition to: :shipped do |obj|
      obj.callback_log << :before_ship
    end

    after_transition to: :paid do |obj|
      obj.callback_log << :paid_callback
    end

    after_transition to: :cancelled do |obj|
      obj.callback_log << :cancelled_callback
    end
  end
end

class TestTrafficLight
  include Philiprehberger::StateMachine

  attr_accessor :callback_log

  def initialize
    @callback_log = []
  end

  state_machine initial: :green do
    event :caution do
      transition from: :green, to: :yellow
    end

    event :stop do
      transition from: :yellow, to: :red
    end

    event :go do
      transition from: :red, to: :green
    end

    event :blink do
      transition from: :yellow, to: :yellow
    end

    before_transition from: :green do |obj|
      obj.callback_log << :leaving_green
    end

    before_transition from: :green, to: :yellow do |obj|
      obj.callback_log << :green_to_yellow
    end

    after_transition do |obj|
      obj.callback_log << :any_after
    end

    after_transition from: %i[green yellow], to: :yellow do |obj|
      obj.callback_log << :arrived_yellow
    end
  end
end

class TestDocument
  include Philiprehberger::StateMachine

  attr_accessor :reviewers, :callback_log

  def initialize(reviewers: [])
    @reviewers = reviewers
    @callback_log = []
  end

  state_machine initial: :draft do
    event :submit do
      transition from: :draft, to: :review, guard: -> { reviewers.any? }
    end

    event :approve do
      transition from: :review, to: :approved
    end

    event :reject do
      transition from: :review, to: :draft
    end

    before_transition to: :review do |obj|
      obj.callback_log << :before_review
    end

    after_transition to: :review do |obj|
      obj.callback_log << :after_review
    end

    before_transition to: :draft do |obj|
      obj.callback_log << :before_draft
    end

    after_transition to: :draft do |obj|
      obj.callback_log << :after_draft
    end
  end
end

class TestAutoTransition
  include Philiprehberger::StateMachine

  attr_accessor :callback_log

  def initialize
    @callback_log = []
  end

  state_machine initial: :pending do
    event :activate do
      transition from: :pending, to: :active
    end

    event :complete do
      transition from: :active, to: :completed
    end

    auto_transition from: :pending, to: :expired, after: 300

    auto_transition from: :active, to: :timed_out, after: 600, guard: -> { !@keep_alive }

    after_transition to: :expired do |obj|
      obj.callback_log << :expired_callback
    end
  end
end

class TestParallelStates
  include Philiprehberger::StateMachine

  state_machine initial: :idle do
    event :start_processing do
      transition from: :idle, to: :processing
      parallel_states :uploading, :validating
    end

    event :finish do
      transition from: :processing, to: :done
    end
  end
end

class TestUnreachable
  include Philiprehberger::StateMachine

  state_machine initial: :a do
    event :go_b do
      transition from: :a, to: :b
    end

    event :go_c do
      transition from: :b, to: :c
    end

    event :go_orphan do
      transition from: :orphan, to: :orphan_target
    end
  end
end

class TestFullyConnected
  include Philiprehberger::StateMachine

  state_machine initial: :a do
    event :go_b do
      transition from: :a, to: :b
    end

    event :go_a do
      transition from: :b, to: :a
    end
  end
end

class TestFinalStates
  include Philiprehberger::StateMachine

  state_machine initial: :pending do
    state :done, final: true
    state :cancelled, final: true
    state :pending

    event :complete do
      transition from: :pending, to: :done
    end

    event :cancel do
      transition from: :pending, to: :cancelled
    end
  end
end

RSpec.describe Philiprehberger::StateMachine do
  it 'has a version number' do
    expect(Philiprehberger::StateMachine::VERSION).not_to be_nil
  end

  describe 'initial state' do
    it 'sets the initial state correctly' do
      order = TestOrder.new
      expect(order.current_state).to eq(:pending)
    end
  end

  describe 'valid transitions' do
    it 'changes state with bang method' do
      order = TestOrder.new
      order.pay!
      expect(order.current_state).to eq(:paid)
    end

    it 'changes state with safe method and returns true' do
      order = TestOrder.new
      result = order.pay
      expect(result).to be true
      expect(order.current_state).to eq(:paid)
    end
  end

  describe 'invalid transitions' do
    it 'raises InvalidTransition with bang method' do
      order = TestOrder.new
      expect { order.ship! }.to raise_error(Philiprehberger::StateMachine::InvalidTransition)
    end

    it 'returns false with safe method' do
      order = TestOrder.new
      result = order.ship
      expect(result).to be false
      expect(order.current_state).to eq(:pending)
    end
  end

  describe 'guards' do
    it 'blocks transition when guard returns false' do
      order = TestOrder.new
      order.pay!
      expect(order.current_state).to eq(:paid)

      expect { order.ship! }.to raise_error(Philiprehberger::StateMachine::InvalidTransition)
      expect(order.current_state).to eq(:paid)
    end

    it 'allows transition when guard returns true' do
      order = TestOrder.new
      order.pay!
      order.tracking_number = 'TRACK123'
      order.ship!
      expect(order.current_state).to eq(:shipped)
    end

    it 'safe method returns false when guard fails' do
      order = TestOrder.new
      order.pay!
      result = order.ship
      expect(result).to be false
    end
  end

  describe 'multiple from states' do
    it 'allows cancel from pending' do
      order = TestOrder.new
      order.cancel!
      expect(order.current_state).to eq(:cancelled)
    end

    it 'allows cancel from paid' do
      order = TestOrder.new
      order.pay!
      order.cancel!
      expect(order.current_state).to eq(:cancelled)
    end
  end

  describe 'state predicates' do
    it 'returns true for the current state' do
      order = TestOrder.new
      expect(order.pending?).to be true
      expect(order.paid?).to be false
    end

    it 'updates after transition' do
      order = TestOrder.new
      order.pay!
      expect(order.pending?).to be false
      expect(order.paid?).to be true
    end
  end

  describe '#can_X?' do
    it 'returns true when transition is valid' do
      order = TestOrder.new
      expect(order.can_pay?).to be true
    end

    it 'returns false when transition is invalid' do
      order = TestOrder.new
      expect(order.can_ship?).to be false
    end

    it 'returns false when guard fails' do
      order = TestOrder.new
      order.pay!
      expect(order.can_ship?).to be false
    end

    it 'returns true when guard passes' do
      order = TestOrder.new
      order.pay!
      order.tracking_number = 'TRACK123'
      expect(order.can_ship?).to be true
    end
  end

  describe '#allowed_transitions' do
    it 'lists valid events from current state' do
      order = TestOrder.new
      expect(order.allowed_transitions).to contain_exactly(:pay, :cancel)
    end

    it 'updates after transition' do
      order = TestOrder.new
      order.pay!
      order.tracking_number = 'TRACK123'
      expect(order.allowed_transitions).to contain_exactly(:ship, :cancel)
    end

    it 'excludes events blocked by guards' do
      order = TestOrder.new
      order.pay!
      expect(order.allowed_transitions).to contain_exactly(:cancel)
    end

    it 'returns empty array when no transitions are valid' do
      order = TestOrder.new
      order.pay!
      order.tracking_number = 'TRACK123'
      order.ship!
      order.deliver!
      expect(order.allowed_transitions).to be_empty
    end
  end

  describe 'before callbacks' do
    it 'fires before state change' do
      order = TestOrder.new
      order.pay!
      order.tracking_number = 'TRACK123'
      order.ship!
      expect(order.callback_log).to include(:before_ship)
    end
  end

  describe 'after callbacks' do
    it 'fires after state change' do
      order = TestOrder.new
      order.pay!
      expect(order.callback_log).to include(:paid_callback)
    end
  end

  describe 'callback filtering by to: state' do
    it 'only fires callback for matching target state' do
      order = TestOrder.new
      order.pay!
      expect(order.callback_log).to include(:paid_callback)
      expect(order.callback_log).not_to include(:cancelled_callback)
    end

    it 'fires correct callback on cancel' do
      order = TestOrder.new
      order.cancel!
      expect(order.callback_log).to include(:cancelled_callback)
      expect(order.callback_log).not_to include(:paid_callback)
    end
  end

  describe 'multiple events and states together' do
    it 'supports a full lifecycle' do
      order = TestOrder.new
      expect(order.current_state).to eq(:pending)

      order.pay!
      expect(order.current_state).to eq(:paid)

      order.tracking_number = 'TRACK123'
      order.ship!
      expect(order.current_state).to eq(:shipped)

      order.deliver!
      expect(order.current_state).to eq(:delivered)
    end
  end

  describe 'guard returning false blocks transition with safe method' do
    it 'does not change state when guard fails' do
      order = TestOrder.new
      order.pay!
      order.tracking_number = nil
      result = order.ship
      expect(result).to be false
      expect(order.current_state).to eq(:paid)
    end
  end

  describe 'callback execution order' do
    it 'fires before_transition before after_transition' do
      order = TestOrder.new
      order.pay!
      order.tracking_number = 'TRACK123'
      order.callback_log.clear
      order.ship!
      expect(order.callback_log.first).to eq(:before_ship)
    end
  end

  describe 'invalid event raises on bang' do
    it 'raises InvalidTransition for deliver from pending' do
      order = TestOrder.new
      expect { order.deliver! }.to raise_error(Philiprehberger::StateMachine::InvalidTransition)
    end

    it 'includes event and state info in error message' do
      order = TestOrder.new
      expect { order.deliver! }.to raise_error(/Cannot deliver from pending/)
    end
  end

  describe 'predicate methods for all states' do
    it 'generates shipped? predicate' do
      order = TestOrder.new
      expect(order.shipped?).to be false
      order.pay!
      order.tracking_number = 'T1'
      order.ship!
      expect(order.shipped?).to be true
    end

    it 'generates delivered? predicate' do
      order = TestOrder.new
      expect(order.delivered?).to be false
    end

    it 'generates cancelled? predicate' do
      order = TestOrder.new
      order.cancel!
      expect(order.cancelled?).to be true
    end
  end

  describe 'allowed_transitions accuracy' do
    it 'returns only cancel for cancelled state' do
      order = TestOrder.new
      order.cancel!
      expect(order.allowed_transitions).to be_empty
    end

    it 'includes ship when guard passes' do
      order = TestOrder.new
      order.pay!
      order.tracking_number = 'T1'
      expect(order.allowed_transitions).to include(:ship)
    end

    it 'excludes ship when guard fails' do
      order = TestOrder.new
      order.pay!
      expect(order.allowed_transitions).not_to include(:ship)
    end
  end

  describe 'can_X? with multiple from states' do
    it 'can_cancel? from pending' do
      order = TestOrder.new
      expect(order.can_cancel?).to be true
    end

    it 'can_cancel? from paid' do
      order = TestOrder.new
      order.pay!
      expect(order.can_cancel?).to be true
    end

    it 'cannot cancel from shipped' do
      order = TestOrder.new
      order.pay!
      order.tracking_number = 'T1'
      order.ship!
      expect(order.can_cancel?).to be false
    end
  end

  describe 'self-transitions' do
    it 'allows transitioning to the same state' do
      light = TestTrafficLight.new
      light.caution!
      expect(light.current_state).to eq(:yellow)
      light.blink!
      expect(light.current_state).to eq(:yellow)
    end

    it 'fires callbacks on self-transition' do
      light = TestTrafficLight.new
      light.caution!
      light.callback_log.clear
      light.blink!
      expect(light.callback_log).to include(:any_after)
    end

    it 'returns true from safe method on self-transition' do
      light = TestTrafficLight.new
      light.caution!
      result = light.blink
      expect(result).to be true
    end

    it 'can_blink? returns true from yellow' do
      light = TestTrafficLight.new
      light.caution!
      expect(light.can_blink?).to be true
    end

    it 'can_blink? returns false from non-yellow state' do
      light = TestTrafficLight.new
      expect(light.can_blink?).to be false
    end
  end

  describe 'callback filtering by from: state' do
    it 'fires callback matching the from state' do
      light = TestTrafficLight.new
      light.callback_log.clear
      light.caution!
      expect(light.callback_log).to include(:leaving_green)
    end

    it 'does not fire from: callback when from state does not match' do
      light = TestTrafficLight.new
      light.caution!
      light.callback_log.clear
      light.stop!
      expect(light.callback_log).not_to include(:leaving_green)
    end
  end

  describe 'callback filtering by from: and to: combined' do
    it 'fires callback when both from and to match' do
      light = TestTrafficLight.new
      light.callback_log.clear
      light.caution!
      expect(light.callback_log).to include(:green_to_yellow)
    end

    it 'does not fire when only from matches but to does not' do
      # There is no transition from green that goes to red directly,
      # so :green_to_yellow should only fire for green->yellow
      light = TestTrafficLight.new
      light.callback_log.clear
      light.caution!
      # :green_to_yellow fires for green->yellow, verify it is present
      expect(light.callback_log).to include(:green_to_yellow)
      # now verify stopping (yellow->red) does NOT fire :green_to_yellow
      light.callback_log.clear
      light.stop!
      expect(light.callback_log).not_to include(:green_to_yellow)
    end
  end

  describe 'callback with array from: condition' do
    it 'fires when from state is in the array' do
      light = TestTrafficLight.new
      light.callback_log.clear
      light.caution! # green -> yellow
      expect(light.callback_log).to include(:arrived_yellow)
    end

    it 'fires for self-transition matching array condition' do
      light = TestTrafficLight.new
      light.caution! # green -> yellow
      light.callback_log.clear
      light.blink! # yellow -> yellow
      expect(light.callback_log).to include(:arrived_yellow)
    end
  end

  describe 'unconditional after callback' do
    it 'fires on every transition' do
      light = TestTrafficLight.new
      light.callback_log.clear
      light.caution!
      expect(light.callback_log).to include(:any_after)

      light.callback_log.clear
      light.stop!
      expect(light.callback_log).to include(:any_after)

      light.callback_log.clear
      light.go!
      expect(light.callback_log).to include(:any_after)
    end
  end

  describe 'guard with constructor keyword arguments' do
    it 'blocks submit when reviewers are empty' do
      doc = TestDocument.new(reviewers: [])
      expect(doc.can_submit?).to be false
      expect { doc.submit! }.to raise_error(Philiprehberger::StateMachine::InvalidTransition)
    end

    it 'allows submit when reviewers are present' do
      doc = TestDocument.new(reviewers: ['Alice'])
      expect(doc.can_submit?).to be true
      doc.submit!
      expect(doc.current_state).to eq(:review)
    end
  end

  describe 'revert transitions (review -> draft)' do
    it 'returns to a previously visited state' do
      doc = TestDocument.new(reviewers: ['Alice'])
      doc.submit!
      expect(doc.current_state).to eq(:review)
      doc.reject!
      expect(doc.current_state).to eq(:draft)
    end

    it 'fires callbacks for the revert transition' do
      doc = TestDocument.new(reviewers: ['Alice'])
      doc.submit!
      doc.callback_log.clear
      doc.reject!
      expect(doc.callback_log).to include(:before_draft)
      expect(doc.callback_log).to include(:after_draft)
    end

    it 'allows re-submitting after rejection' do
      doc = TestDocument.new(reviewers: ['Alice'])
      doc.submit!
      doc.reject!
      expect(doc.current_state).to eq(:draft)
      doc.submit!
      expect(doc.current_state).to eq(:review)
    end
  end

  describe 'callback ordering with multiple callbacks' do
    it 'fires before callbacks before state change and after callbacks after' do
      doc = TestDocument.new(reviewers: ['Alice'])
      doc.callback_log.clear
      doc.submit!
      before_idx = doc.callback_log.index(:before_review)
      after_idx = doc.callback_log.index(:after_review)
      expect(before_idx).to be < after_idx
    end

    it 'fires multiple matching callbacks in registration order' do
      light = TestTrafficLight.new
      light.callback_log.clear
      light.caution! # green -> yellow
      # :leaving_green (before, from: green) comes before :green_to_yellow (before, from: green, to: yellow)
      leaving_idx = light.callback_log.index(:leaving_green)
      combined_idx = light.callback_log.index(:green_to_yellow)
      expect(leaving_idx).to be < combined_idx
    end
  end

  describe 'class-level introspection' do
    it 'exposes the definition via _sm_definition' do
      defn = TestOrder._sm_definition
      expect(defn).to be_a(Philiprehberger::StateMachine::Definition)
      expect(defn.initial).to eq(:pending)
    end

    it 'lists all events on the definition' do
      defn = TestOrder._sm_definition
      expect(defn.events.keys).to contain_exactly(:pay, :ship, :deliver, :cancel)
    end

    it 'returns all unique states via all_states' do
      defn = TestOrder._sm_definition
      expect(defn.all_states).to contain_exactly(:pending, :paid, :shipped, :delivered, :cancelled)
    end
  end

  describe 'Transition struct' do
    it '#matches? returns true for matching single from state' do
      t = Philiprehberger::StateMachine::Transition.new(from: :a, to: :b)
      expect(t.matches?(:a)).to be true
    end

    it '#matches? returns false for non-matching state' do
      t = Philiprehberger::StateMachine::Transition.new(from: :a, to: :b)
      expect(t.matches?(:c)).to be false
    end

    it '#matches? works with array of from states' do
      t = Philiprehberger::StateMachine::Transition.new(from: %i[a b], to: :c)
      expect(t.matches?(:a)).to be true
      expect(t.matches?(:b)).to be true
      expect(t.matches?(:d)).to be false
    end

    it '#from_states returns array for single from' do
      t = Philiprehberger::StateMachine::Transition.new(from: :x, to: :y)
      expect(t.from_states).to eq([:x])
    end

    it '#from_states returns array as-is for array from' do
      t = Philiprehberger::StateMachine::Transition.new(from: %i[x y], to: :z)
      expect(t.from_states).to eq(%i[x y])
    end
  end

  describe 'error class hierarchy' do
    it 'InvalidTransition is a subclass of Error' do
      expect(Philiprehberger::StateMachine::InvalidTransition).to be < Philiprehberger::StateMachine::Error
    end

    it 'Error is a subclass of StandardError' do
      expect(Philiprehberger::StateMachine::Error).to be < StandardError
    end

    it 'InvalidTransition can be rescued as Error' do
      order = TestOrder.new
      rescued = false
      begin
        order.deliver!
      rescue Philiprehberger::StateMachine::Error
        rescued = true
      end
      expect(rescued).to be true
    end
  end

  describe 'state unchanged after failed bang transition' do
    it 'does not change state when guard fails on bang' do
      order = TestOrder.new
      order.pay!
      expect do
        order.ship!
      end.to raise_error(Philiprehberger::StateMachine::InvalidTransition)
      expect(order.current_state).to eq(:paid)
    end

    it 'does not change state when no valid transition on bang' do
      order = TestOrder.new
      expect do
        order.deliver!
      end.to raise_error(Philiprehberger::StateMachine::InvalidTransition)
      expect(order.current_state).to eq(:pending)
    end
  end

  describe 'guard error message content' do
    it 'includes guard failure info in the error message' do
      order = TestOrder.new
      order.pay!
      expect { order.ship! }.to raise_error(/Guard condition failed for ship from paid/)
    end
  end

  describe 'TrafficLight full cycle' do
    it 'completes a full green -> yellow -> red -> green cycle' do
      light = TestTrafficLight.new
      expect(light.current_state).to eq(:green)
      light.caution!
      expect(light.current_state).to eq(:yellow)
      light.stop!
      expect(light.current_state).to eq(:red)
      light.go!
      expect(light.current_state).to eq(:green)
    end
  end

  describe 'TrafficLight state predicates' do
    it 'generates predicates for all traffic light states' do
      light = TestTrafficLight.new
      expect(light.green?).to be true
      expect(light.yellow?).to be false
      expect(light.red?).to be false
    end
  end

  describe 'TrafficLight allowed_transitions' do
    it 'returns caution from green' do
      light = TestTrafficLight.new
      expect(light.allowed_transitions).to contain_exactly(:caution)
    end

    it 'returns stop and blink from yellow' do
      light = TestTrafficLight.new
      light.caution!
      expect(light.allowed_transitions).to contain_exactly(:stop, :blink)
    end

    it 'returns go from red' do
      light = TestTrafficLight.new
      light.caution!
      light.stop!
      expect(light.allowed_transitions).to contain_exactly(:go)
    end
  end

  # ===== NEW FEATURE TESTS =====

  describe 'state history tracking' do
    it 'records the initial state in history' do
      order = TestOrder.new
      history = order.state_history
      expect(history.size).to eq(1)
      expect(history.first[:state]).to eq(:pending)
      expect(history.first[:entered_at]).to be_a(Time)
    end

    it 'records transitions in history' do
      order = TestOrder.new
      order.pay!
      history = order.state_history
      expect(history.size).to eq(2)
      expect(history.map { |h| h[:state] }).to eq(%i[pending paid])
    end

    it 'records full lifecycle in history' do
      order = TestOrder.new
      order.pay!
      order.tracking_number = 'T1'
      order.ship!
      order.deliver!
      history = order.state_history
      expect(history.size).to eq(4)
      expect(history.map { |h| h[:state] }).to eq(%i[pending paid shipped delivered])
    end

    it 'includes timestamps for each entry' do
      order = TestOrder.new
      order.pay!
      history = order.state_history
      history.each do |entry|
        expect(entry[:entered_at]).to be_a(Time)
      end
    end

    it 'returns previous_state correctly' do
      order = TestOrder.new
      expect(order.previous_state).to be_nil
      order.pay!
      expect(order.previous_state).to eq(:pending)
      order.tracking_number = 'T1'
      order.ship!
      expect(order.previous_state).to eq(:paid)
    end

    it 'tracks history with safe transition method' do
      order = TestOrder.new
      order.pay
      history = order.state_history
      expect(history.size).to eq(2)
      expect(history.last[:state]).to eq(:paid)
    end

    it 'does not add history entry on failed transition' do
      order = TestOrder.new
      order.ship # fails silently
      history = order.state_history
      expect(history.size).to eq(1)
    end

    it 'tracks self-transitions in history' do
      light = TestTrafficLight.new
      light.caution!
      light.blink!
      history = light.state_history
      expect(history.size).to eq(3)
      expect(history.map { |h| h[:state] }).to eq(%i[green yellow yellow])
    end
  end

  describe 'transition statistics' do
    it 'starts with zero transition count' do
      order = TestOrder.new
      expect(order.transition_count).to eq(0)
    end

    it 'increments transition count on each transition' do
      order = TestOrder.new
      order.pay!
      expect(order.transition_count).to eq(1)
      order.tracking_number = 'T1'
      order.ship!
      expect(order.transition_count).to eq(2)
    end

    it 'counts transitions with safe method' do
      order = TestOrder.new
      order.pay
      expect(order.transition_count).to eq(1)
    end

    it 'does not count failed transitions' do
      order = TestOrder.new
      order.ship # fails
      expect(order.transition_count).to eq(0)
    end

    it 'returns time_in_state as a positive number' do
      order = TestOrder.new
      time = order.time_in_state(:pending)
      expect(time).to be >= 0
    end

    it 'returns zero for unvisited states' do
      order = TestOrder.new
      expect(order.time_in_state(:paid)).to eq(0)
    end

    it 'returns transition_stats as a hash' do
      order = TestOrder.new
      order.pay!
      stats = order.transition_stats
      expect(stats).to be_a(Hash)
      expect(stats[:total_transitions]).to eq(1)
      expect(stats[:transition_counts]).to include(pending_to_paid: 1)
      expect(stats[:time_in_states]).to be_a(Hash)
    end

    it 'tracks multiple transition types' do
      light = TestTrafficLight.new
      light.caution!
      light.stop!
      light.go!
      stats = light.transition_stats
      expect(stats[:total_transitions]).to eq(3)
      expect(stats[:transition_counts][:green_to_yellow]).to eq(1)
      expect(stats[:transition_counts][:yellow_to_red]).to eq(1)
      expect(stats[:transition_counts][:red_to_green]).to eq(1)
    end

    it 'counts repeated transitions' do
      light = TestTrafficLight.new
      light.caution!
      light.blink!
      light.blink!
      stats = light.transition_stats
      expect(stats[:transition_counts][:yellow_to_yellow]).to eq(2)
    end
  end

  describe 'timed/automatic transitions' do
    it 'does not auto-transition before time has elapsed' do
      obj = TestAutoTransition.new
      result = obj.check_auto_transitions!
      expect(result).to be false
      expect(obj.current_state).to eq(:pending)
    end

    it 'auto-transitions when time has elapsed' do
      obj = TestAutoTransition.new
      # Simulate time passing by manipulating the entered_at time
      obj.instance_variable_set(:@_sm_state_entered_at, Time.now - 301)
      result = obj.check_auto_transitions!
      expect(result).to be true
      expect(obj.current_state).to eq(:expired)
    end

    it 'fires callbacks on auto-transition' do
      obj = TestAutoTransition.new
      obj.instance_variable_set(:@_sm_state_entered_at, Time.now - 301)
      obj.check_auto_transitions!
      expect(obj.callback_log).to include(:expired_callback)
    end

    it 'records auto-transition in history' do
      obj = TestAutoTransition.new
      obj.instance_variable_set(:@_sm_state_entered_at, Time.now - 301)
      obj.check_auto_transitions!
      history = obj.state_history
      expect(history.map { |h| h[:state] }).to eq(%i[pending expired])
    end

    it 'records auto-transition in statistics' do
      obj = TestAutoTransition.new
      obj.instance_variable_set(:@_sm_state_entered_at, Time.now - 301)
      obj.check_auto_transitions!
      expect(obj.transition_count).to eq(1)
    end

    it 'respects guard on auto-transition' do
      obj = TestAutoTransition.new
      obj.activate!
      obj.instance_variable_set(:@_sm_state_entered_at, Time.now - 601)
      obj.instance_variable_set(:@keep_alive, true)
      result = obj.check_auto_transitions!
      expect(result).to be false
      expect(obj.current_state).to eq(:active)
    end

    it 'auto-transitions when guard passes' do
      obj = TestAutoTransition.new
      obj.activate!
      obj.instance_variable_set(:@_sm_state_entered_at, Time.now - 601)
      obj.instance_variable_set(:@keep_alive, false)
      result = obj.check_auto_transitions!
      expect(result).to be true
      expect(obj.current_state).to eq(:timed_out)
    end

    it 'includes auto_transition states in all_states' do
      defn = TestAutoTransition._sm_definition
      expect(defn.all_states).to include(:expired, :timed_out)
    end
  end

  describe 'parallel/concurrent states' do
    it 'starts with no parallel states' do
      obj = TestParallelStates.new
      expect(obj.parallel_states).to be_empty
    end

    it 'activates parallel states on transition' do
      obj = TestParallelStates.new
      obj.start_processing!
      expect(obj.parallel_states).to contain_exactly(:uploading, :validating)
    end

    it 'checks individual parallel state activity' do
      obj = TestParallelStates.new
      obj.start_processing!
      expect(obj.parallel_state_active?(:uploading)).to be true
      expect(obj.parallel_state_active?(:validating)).to be true
      expect(obj.parallel_state_active?(:other)).to be false
    end

    it 'deactivates parallel states on next transition without parallel_states' do
      obj = TestParallelStates.new
      obj.start_processing!
      expect(obj.parallel_states).not_to be_empty
      obj.finish!
      expect(obj.parallel_states).to be_empty
    end

    it 'works with safe transition method' do
      obj = TestParallelStates.new
      obj.start_processing
      expect(obj.parallel_states).to contain_exactly(:uploading, :validating)
    end
  end

  describe 'DOT/GraphViz export' do
    it 'generates valid DOT output' do
      dot = TestOrder.to_dot
      expect(dot).to include('digraph')
      expect(dot).to include('rankdir=LR')
    end

    it 'includes initial state indicator' do
      dot = TestOrder.to_dot
      expect(dot).to include('__start__')
      expect(dot).to include('__start__ -> pending')
    end

    it 'includes all state nodes' do
      dot = TestOrder.to_dot
      expect(dot).to include('pending [shape=ellipse]')
      expect(dot).to include('paid [shape=ellipse]')
      expect(dot).to include('shipped [shape=ellipse]')
      expect(dot).to include('delivered [shape=ellipse]')
      expect(dot).to include('cancelled [shape=ellipse]')
    end

    it 'includes transition edges with event labels' do
      dot = TestOrder.to_dot
      expect(dot).to include('pending -> paid [label="pay"]')
      expect(dot).to include('shipped -> delivered [label="deliver"]')
    end

    it 'marks guarded transitions' do
      dot = TestOrder.to_dot
      expect(dot).to include('paid -> shipped [label="ship [guarded]"]')
    end

    it 'includes transitions from multiple source states' do
      dot = TestOrder.to_dot
      expect(dot).to include('pending -> cancelled [label="cancel"]')
      expect(dot).to include('paid -> cancelled [label="cancel"]')
    end

    it 'accepts a custom graph name' do
      dot = TestOrder.to_dot(name: 'OrderFlow')
      expect(dot).to include('digraph OrderFlow')
    end

    it 'includes auto-transitions with dashed style' do
      dot = TestAutoTransition.to_dot
      expect(dot).to include('pending -> expired [label="auto(300s)", style=dashed]')
    end

    it 'raises error when no state machine is defined' do
      klass = Class.new { include Philiprehberger::StateMachine }
      expect { klass.to_dot }.to raise_error(Philiprehberger::StateMachine::Error)
    end
  end

  describe 'unreachable state detection' do
    it 'detects unreachable states' do
      unreachable = TestUnreachable.unreachable_states
      expect(unreachable).to include(:orphan)
      expect(unreachable).to include(:orphan_target)
    end

    it 'does not flag reachable states' do
      unreachable = TestUnreachable.unreachable_states
      expect(unreachable).not_to include(:a)
      expect(unreachable).not_to include(:b)
      expect(unreachable).not_to include(:c)
    end

    it 'returns empty array when all states are reachable' do
      unreachable = TestFullyConnected.unreachable_states
      expect(unreachable).to be_empty
    end

    it 'returns empty for simple linear machine' do
      unreachable = TestOrder.unreachable_states
      expect(unreachable).to be_empty
    end

    it 'raises error when no state machine is defined' do
      klass = Class.new { include Philiprehberger::StateMachine }
      expect { klass.unreachable_states }.to raise_error(Philiprehberger::StateMachine::Error)
    end
  end

  describe 'Validation module' do
    it 'finds reachable states via BFS' do
      defn = TestUnreachable._sm_definition
      reachable = Philiprehberger::StateMachine::Validation.reachable_states(defn)
      expect(reachable).to contain_exactly(:a, :b, :c)
    end

    it 'finds predecessors of a state' do
      defn = TestOrder._sm_definition
      preds = Philiprehberger::StateMachine::Validation.predecessors(defn, :cancelled)
      expect(preds).to contain_exactly(:pending, :paid)
    end

    it 'returns empty predecessors for initial state with no inbound transitions' do
      defn = TestUnreachable._sm_definition
      preds = Philiprehberger::StateMachine::Validation.predecessors(defn, :a)
      expect(preds).to be_empty
    end
  end

  describe 'History class' do
    it 'respects max_size limit' do
      history = Philiprehberger::StateMachine::History.new(:start, max_size: 3)
      history.record(:a)
      history.record(:b)
      history.record(:c)
      # Now has 4 entries (start + 3), should trim to 3
      expect(history.size).to eq(3)
      expect(history.entries.first[:state]).to eq(:a)
    end
  end

  describe 'Statistics class' do
    it 'tracks time in current state' do
      stats = Philiprehberger::StateMachine::Statistics.new(:idle)
      time = stats.time_in_state(:idle)
      expect(time).to be >= 0
    end
  end

  describe 'on_enter and on_exit hooks' do
    let(:klass) do
      Class.new do
        include Philiprehberger::StateMachine

        attr_reader :hook_log

        state_machine initial: :idle do
          on_enter(:active) { |obj| obj.instance_variable_get(:@hook_log) << 'enter_active' }
          on_exit(:idle) { |obj| obj.instance_variable_get(:@hook_log) << 'exit_idle' }
          on_enter(:done) { |obj| obj.instance_variable_get(:@hook_log) << 'enter_done' }

          event :start do
            transition from: :idle, to: :active
          end

          event :finish do
            transition from: :active, to: :done
          end
        end

        def initialize
          @hook_log = []
          super
        end
      end
    end

    it 'fires on_exit when leaving a state' do
      obj = klass.new
      obj.start!
      expect(obj.hook_log).to include('exit_idle')
    end

    it 'fires on_enter when entering a state' do
      obj = klass.new
      obj.start!
      expect(obj.hook_log).to include('enter_active')
    end

    it 'fires hooks in correct order' do
      obj = klass.new
      obj.start!
      expect(obj.hook_log).to eq(%w[exit_idle enter_active])
    end

    it 'fires hooks on subsequent transitions' do
      obj = klass.new
      obj.start!
      obj.finish!
      expect(obj.hook_log).to include('enter_done')
    end
  end

  describe '#time_in_current_state' do
    let(:klass) do
      Class.new do
        include Philiprehberger::StateMachine

        state_machine initial: :idle do
          event :start do
            transition from: :idle, to: :active
          end
        end
      end
    end

    it 'returns elapsed time in current state' do
      obj = klass.new
      sleep 0.01
      expect(obj.time_in_current_state).to be > 0
    end

    it 'resets after transition' do
      obj = klass.new
      sleep 0.05
      obj.start!
      expect(obj.time_in_current_state).to be < 0.05
    end
  end

  describe 'event payload' do
    let(:payload_klass) do
      Class.new do
        include Philiprehberger::StateMachine

        attr_reader :log

        state_machine initial: :pending do
          event :pay do
            transition from: :pending, to: :paid, guard: ->(amount:, **) { amount > 0 }
          end

          event :ship do
            transition from: :paid, to: :shipped
          end

          event :cancel do
            transition from: %i[pending paid], to: :cancelled
          end

          before_transition to: :paid do |obj, payload|
            obj.instance_variable_get(:@log) << { before: payload }
          end

          after_transition to: :paid do |obj, payload|
            obj.instance_variable_get(:@log) << { after: payload }
          end

          # Arity-1 callback to test backwards compatibility
          after_transition to: :shipped do |obj|
            obj.instance_variable_get(:@log) << :shipped_no_payload
          end

          on_enter(:paid) { |obj, payload| obj.instance_variable_get(:@log) << { enter: payload } }
          on_exit(:pending) { |obj, payload| obj.instance_variable_get(:@log) << { exit: payload } }

          # Arity-1 hook to test backwards compatibility
          on_enter(:cancelled) { |obj| obj.instance_variable_get(:@log) << :cancelled_enter }
        end

        def initialize
          @log = []
          super
        end
      end
    end

    it 'forwards payload to guard via keyword arguments' do
      obj = payload_klass.new
      obj.pay!(amount: 50)
      expect(obj.current_state).to eq(:paid)
    end

    it 'guard rejects based on payload value' do
      obj = payload_klass.new
      expect { obj.pay!(amount: 0) }.to raise_error(Philiprehberger::StateMachine::InvalidTransition)
      expect(obj.current_state).to eq(:pending)
    end

    it 'safe method returns false when guard rejects payload' do
      obj = payload_klass.new
      result = obj.pay(amount: -1)
      expect(result).to be false
    end

    it 'forwards payload to before_transition callback' do
      obj = payload_klass.new
      obj.pay!(amount: 100, method: :card)
      before_entry = obj.log.find { |e| e.is_a?(Hash) && e[:before] }
      expect(before_entry[:before]).to eq({ amount: 100, method: :card })
    end

    it 'forwards payload to after_transition callback' do
      obj = payload_klass.new
      obj.pay!(amount: 100)
      after_entry = obj.log.find { |e| e.is_a?(Hash) && e[:after] }
      expect(after_entry[:after]).to eq({ amount: 100 })
    end

    it 'forwards payload to on_enter hook' do
      obj = payload_klass.new
      obj.pay!(amount: 75)
      enter_entry = obj.log.find { |e| e.is_a?(Hash) && e[:enter] }
      expect(enter_entry[:enter]).to eq({ amount: 75 })
    end

    it 'forwards payload to on_exit hook' do
      obj = payload_klass.new
      obj.pay!(amount: 25)
      exit_entry = obj.log.find { |e| e.is_a?(Hash) && e[:exit] }
      expect(exit_entry[:exit]).to eq({ amount: 25 })
    end

    it 'backwards compatible with arity-1 callbacks' do
      obj = payload_klass.new
      obj.pay!(amount: 10)
      obj.ship!
      expect(obj.log).to include(:shipped_no_payload)
    end

    it 'backwards compatible with arity-1 on_enter hooks' do
      obj = payload_klass.new
      obj.cancel!
      expect(obj.log).to include(:cancelled_enter)
    end

    it 'works with safe method and payload' do
      obj = payload_klass.new
      result = obj.pay(amount: 50)
      expect(result).to be true
      expect(obj.current_state).to eq(:paid)
    end

    it 'can_X? accepts payload for guard evaluation' do
      obj = payload_klass.new
      expect(obj.can_pay?(amount: 100)).to be true
      expect(obj.can_pay?(amount: 0)).to be false
    end

    it 'events without payload still work' do
      obj = payload_klass.new
      obj.pay!(amount: 10)
      obj.ship!
      expect(obj.current_state).to eq(:shipped)
    end

    it 'payload does not persist between transitions' do
      obj = payload_klass.new
      obj.pay!(amount: 50)
      obj.ship!
      # ship callback should not receive pay's payload
      shipped_entries = obj.log.select { |e| e == :shipped_no_payload }
      expect(shipped_entries.size).to eq(1)
    end
  end

  describe 'final/terminal states' do
    it 'marks a state as final via state :name, final: true' do
      defn = TestFinalStates._sm_definition
      expect(defn.final_state?(:done)).to be true
      expect(defn.final_state?(:cancelled)).to be true
    end

    it 'does not mark non-final states as final' do
      defn = TestFinalStates._sm_definition
      expect(defn.final_state?(:pending)).to be false
    end

    it 'returns true for #final? when in a final state' do
      obj = TestFinalStates.new
      obj.complete!
      expect(obj.final?).to be true
    end

    it 'returns true for #terminal? when in a final state' do
      obj = TestFinalStates.new
      obj.complete!
      expect(obj.terminal?).to be true
    end

    it 'returns false for #final? when not in a final state' do
      obj = TestFinalStates.new
      expect(obj.final?).to be false
    end

    it 'returns false for #terminal? when not in a final state' do
      obj = TestFinalStates.new
      expect(obj.terminal?).to be false
    end

    it 'returns true for #final? in cancelled final state' do
      obj = TestFinalStates.new
      obj.cancel!
      expect(obj.final?).to be true
    end

    it 'still raises InvalidTransition when transitioning from a final state with no outgoing transitions' do
      obj = TestFinalStates.new
      obj.complete!
      expect(obj.final?).to be true
      expect { obj.complete! }.to raise_error(Philiprehberger::StateMachine::InvalidTransition)
      expect { obj.cancel! }.to raise_error(Philiprehberger::StateMachine::InvalidTransition)
    end

    it 'keeps #final? false for gems declaring state without the final: option (backward compat)' do
      # TestOrder is defined without any `state :name, final: true` declarations
      order = TestOrder.new
      expect(order.final?).to be false
      order.pay!
      expect(order.final?).to be false
      order.cancel!
      expect(order.final?).to be false
    end

    it 'exposes final_states on the definition' do
      defn = TestFinalStates._sm_definition
      expect(defn.final_states).to contain_exactly(:done, :cancelled)
    end

    it 'includes declared-only final states in all_states' do
      defn = TestFinalStates._sm_definition
      expect(defn.all_states).to include(:done, :cancelled, :pending)
    end
  end
end
