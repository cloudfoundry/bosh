require 'spec_helper'
require 'json'
require 'bosh/template/renderer'

module Bosh
  module Template
    describe Renderer do
      subject(:renderer) do
        Renderer.new(context: context)
      end

      let(:template) do
        File.join(assets_dir, 'nats.conf.erb')
      end

      let(:rendered) do
        File.join(assets_dir, 'nats.conf')
      end

      let(:context) do
        File.read(File.join(assets_dir, 'nats.json'))
      end

      let(:assets_dir) do
        File.expand_path('../../../assets', File.dirname(__FILE__))
      end

      it 'correctly renders a realistic nats config template' do
        expect(renderer.render(template)).to eq(File.read(rendered))
      end

      context 'backward compatibility' do
        let(:template) do
          File.join(assets_dir, 'backward_compatibility.erb')
        end

        let(:rendered) do
          File.join(assets_dir, 'backward_compatibility')
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
