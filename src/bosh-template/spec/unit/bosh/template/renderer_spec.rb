require 'spec_helper'
require 'bosh/template/renderer' # required as this is only loaded by `bin/bosh-template`

module Bosh
  module Template
    describe Renderer do
      subject(:renderer) do
        Renderer.new(context: context)
      end

      let(:template) do
        asset_path('nats.conf.erb')
      end

      let(:rendered) do
        asset_path('nats.conf')
      end

      let(:context) do
        asset_content('nats.json')
      end

      it 'correctly renders a realistic nats config template' do
        expect(renderer.render(template)).to eq(File.read(rendered))
      end

      context 'backward compatibility' do
        let(:template) do
          asset_path('backward_compatibility.erb')
        end

        let(:rendered) do
          asset_path('backward_compatibility')
        end

        let(:context) do
          JSON.dump({
            "properties": {
                "property": "value"
            }
          })
        end

        it 'correctly renders using backward-compatible Ruby methods' do
          expect(renderer.render(template)).to eq(File.read(rendered))
        end
      end
    end
  end
end
