require 'spec_helper'

module Bosh::Director
  describe BoundedYaml do
    it 'supports ordinary shared aliases without changing their values' do
      parsed = described_class.safe_load("first: &shared {password: value}\nsecond: *shared\n", aliases: true)
      expect(parsed['first']).to eq('password' => 'value')
      expect(parsed['first']).to equal(parsed['second'])
    end

    it 'rejects cycles' do
      expect do
        described_class.safe_load('root: &root {child: *root}', aliases: true)
      end.to raise_error(BadManifest, /cyclic/)
    end

    it 'rejects exponential expansion while retaining a small graph' do
      yaml = "base: &base [value]\n"
      20.times { |i| yaml << "level#{i}: &level#{i} [*#{i.zero? ? 'base' : "level#{i - 1}"}, *#{i.zero? ? 'base' : "level#{i - 1}"}]\n" }
      expect do
        described_class.safe_load(yaml, aliases: true)
      end.to raise_error(BadManifest, /expansion/)
    end

    it 'rejects excessive nesting' do
      expect do
        described_class.safe_load(('[' * 101) + 'value' + (']' * 101))
      end.to raise_error(BadManifest, /depth/)
    end

    it 'checks the depth of shared containers at each reference' do
      leaf = [1]
      object = [leaf, [[leaf]]]
      stub_const('Bosh::Director::BoundedYaml::MAX_DEPTH', 3)
      expect { described_class.validate!(object) }.to raise_error(BadManifest, /depth/)
    end

    it 'allows a graph exactly at its expansion budget' do
      stub_const('Bosh::Director::BoundedYaml::MAX_EXPANDED_NODES', 3)
      expect(described_class.safe_load('[1, 2]')).to eq([1, 2])
    end

    it 'rejects a graph beyond its expansion budget' do
      stub_const('Bosh::Director::BoundedYaml::MAX_EXPANDED_NODES', 2)
      expect { described_class.safe_load('[1, 2]') }.to raise_error(BadManifest, /expansion/)
    end

    it 'guards direct redaction of a cyclic object' do
      object = {}; object['properties'] = object
      expect { Redactor.new.redact_properties!(object) }.to raise_error(BadManifest, /cyclic/)
    end

    it 'guards direct interpolation traversal of a cyclic object' do
      object = []; object << object
      expect { ConfigServer::DeepHashReplacement.new.variables_path(object) }.to raise_error(BadManifest, /cyclic/)
    end
  end
end
