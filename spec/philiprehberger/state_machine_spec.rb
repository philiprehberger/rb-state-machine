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
      transition from: [:pending, :paid], to: :cancelled
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
end
