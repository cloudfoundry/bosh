require 'spec_helper'

module Bosh::Director::DeploymentPlan
  describe PlacementPlanner::Balancer do
    it 'first chooses the item with the lowest count' do
      balancer = PlacementPlanner::Balancer.new(initial_weight: { 'z1' => 0, 'z2' => 1, 'z3' => 2 })
      expect(balancer.pop).to eq('z1')
      balancer = PlacementPlanner::Balancer.new(initial_weight: { 'z1' => 1, 'z2' => 0, 'z3' => 2 })
      expect(balancer.pop).to eq('z2')
      balancer = PlacementPlanner::Balancer.new(initial_weight: { 'z1' => 1, 'z2' => 1, 'z3' => 0 })
      expect(balancer.pop).to eq('z3')
    end

    it 'uses the specified tie-breaking strategy to break ties' do
      balancer = PlacementPlanner::Balancer.new(
        initial_weight: { 'z1' => 0, 'z2' => 0, 'z3' => 2 },
        tie_strategy: lambda {|n| n.min }
      )
      expect(balancer.pop).to eq('z1')
      balancer = PlacementPlanner::Balancer.new(
        initial_weight: { 'z1' => 0, 'z2' => 0, 'z3' => 2 },
        tie_strategy: lambda {|n| n.max }
      )
      expect(balancer.pop).to eq('z2')
    end

    it 'short circuits the tie breaker with a single match' do
      balancer = PlacementPlanner::Balancer.new(
        initial_weight: { 'z1' => 0, 'z2' => 1, 'z3' => 2 },
        tie_strategy: lambda {|n| raise "should not be called" }
      )

      expect { balancer.pop }.to_not raise_error
    end

    it 'rebalances when you pop' do
      balancer = PlacementPlanner::Balancer.new(
        initial_weight: { 'z1' => 0, 'z2' => 0, 'z3' => 2 },
        tie_strategy: lambda {|n| n.max }
      )
      expect(balancer.pop).to eq('z2')
      expect(balancer.pop).to eq('z1')
      expect(balancer.pop).to eq('z2')
      expect(balancer.pop).to eq('z1')
      expect(balancer.pop).to eq('z3')
    end
  end
end
