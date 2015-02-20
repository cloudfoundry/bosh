require 'spec_helper'
require 'bosh/dev/writable_manifest'

module Bosh::Dev
  describe WritableManifest do
    include FakeFS::SpecHelpers

    context 'when mixed into a manifest that implements #to_h' do
      let(:manifest) do
        double('FakeManifest', filename: 'foo.yml', to_h: { 'foo' => 'bar' })
      end

      before do
        manifest.extend(WritableManifest)
      end

      it 'writes it to disk as yaml' do
        expect { manifest.write }.to change { File.exist?('foo.yml') }.to(true)

        expect(File.read('foo.yml')).to eq("---\nfoo: bar\n")
      end
    end
  end
end
