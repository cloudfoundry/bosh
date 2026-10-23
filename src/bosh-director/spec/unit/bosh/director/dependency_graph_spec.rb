require 'spec_helper'

module Bosh::Director
  describe 'Package dependency traversal' do
    def packages(depth)
      (0..depth).map do |i|
        { 'name' => "package#{i}", 'version' => '1', 'dependencies' => i == depth ? [] : ["package#{i + 1}", "package#{i + 1}"] }
      end
    end

    def diamonds(depth)
      (0...depth).flat_map do |i|
        [
          { 'name' => "top#{i}", 'dependencies' => ["left#{i}", "right#{i}"] },
          { 'name' => "left#{i}", 'dependencies' => ["top#{i + 1}"] },
          { 'name' => "right#{i}", 'dependencies' => ["top#{i + 1}"] },
        ]
      end + [{ 'name' => "top#{depth}", 'dependencies' => [] }]
    end

    it 'rejects cyclic dependency keys with a normal error' do
      graph = [{ 'name' => 'root', 'version' => '1', 'dependencies' => ['root'] }]
      expect do
        KeyGenerator.new.dependency_key_from_manifest('root', graph)
      end.to raise_error(ReleaseExistingPackageHashMismatch, /cycle/)
    end

    it 'bounds expanded dependency keys even for a small shared graph' do
      stub_const('Bosh::Director::KeyGenerator::MAX_EXPANDED_DEPENDENCIES', 100)
      expect do
        KeyGenerator.new.dependency_key_from_manifest('package0', packages(10))
      end.to raise_error(ReleaseExistingPackageHashMismatch, /supported size/)
    end

    it 'checks each vertex once in a shared acyclic graph' do
      graph = packages(12).to_h { |p| [p['name'], p['dependencies']] }
      visits = Hash.new(0)
      CycleHelper.check_for_cycle(graph.keys) do |name|
        visits[name] += 1
        graph[name]
      end
      expect(visits.values).to all(eq(1))
    end

    it 'handles a deep acyclic graph without recursive stack growth' do
      vertices = (0...5_000).to_a
      expect do
        CycleHelper.check_for_cycle(vertices) { |i| i == vertices.last ? [] : [i + 1] }
      end.not_to raise_error
    end

    it 'visits each reachable package once when collecting transitive dependencies' do
      graph = diamonds(8)
      model_graph = graph.to_h { |p| [p['name'], Struct.new(:name, :dependency_set).new(p['name'], p['dependencies'])] }
      release = double('release', package_by_name: nil)
      allow(release).to receive(:package_by_name) { |name| model_graph.fetch(name) }
      manager = PackageDependenciesManager.new(release)
      model_graph.each_value { |p| expect(manager).to receive(:dependencies).with(p).once.and_call_original }
      expect(manager.transitive_dependencies(model_graph['top0']).size).to eq(24)
    end
  end
end
