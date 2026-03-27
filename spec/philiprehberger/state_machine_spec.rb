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
end
