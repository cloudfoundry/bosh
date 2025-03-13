require 'spec_helper'

describe Bosh::Director::CycleHelper do
  it 'should detect simple cycles' do
    graph = {
      A: [:B],
      B: [:A],
    }

    expect { Bosh::Director::CycleHelper.check_for_cycle(%i[A B C]) { |vertex| graph[vertex] } }.to raise_error(/Cycle: A=/)
  end

  it 'should detect more complicated cycles' do
    graph = {
      A: [:B],
      B: [:C],
      C: [:D],
      D: [:B],
    }

    expect { Bosh::Director::CycleHelper.check_for_cycle(%i[A B C]) { |vertex| graph[vertex] } }.to raise_error(/Invalid edge: D/)
  end

  it "should not detect cycles when it's acyclic" do
    graph = {
      A: %i[B C],
      B: [:C],
    }

    Bosh::Director::CycleHelper.check_for_cycle(%i[A B C]) { |vertex| graph[vertex] }
  end

  it 'should return connected vertices when requested' do
    graph = {
      A: %i[B C],
      B: [:C],
    }

    result = Bosh::Director::CycleHelper.check_for_cycle(
      %i[A B C], connected_vertices: true
    ) { |vertex| graph[vertex] }

    result[:connected_vertices].each { |key, value| result[:connected_vertices][key] = Set.new(value) }
    expect(result).to eql(connected_vertices: { C: Set.new([]), A: Set.new(%i[C B]), B: Set.new([:C]) })
  end

  it 'should raise an exception when an referenced edge is not found' do
    graph = {
      A: %i[B C],
      B: [:D],
    }

    expect { Bosh::Director::CycleHelper.check_for_cycle(%i[A B C]) { |vertex| graph[vertex] } }.to raise_error(/Invalid edge: D/)
  end
end
