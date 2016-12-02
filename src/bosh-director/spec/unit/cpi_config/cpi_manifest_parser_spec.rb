require 'spec_helper'

module Bosh::Director
  describe CpiConfig::CpiManifestParser do
    subject(:parser) { described_class.new() }
    let(:event_log) { Config.event_log }

    describe '#parse' do
      let(:cpi_manifest) { Bosh::Spec::Deployments.simple_cpi_config }
      let(:parsed_cpis) { subject.parse(cpi_manifest) }

      it "creates a CPI for every entry" do
        expect(parsed_cpis.cpis[0].name).to eq(cpi_manifest['cpis'][0]['name'])
        expect(parsed_cpis.cpis[0].type).to eq(cpi_manifest['cpis'][0]['type'])
        expect(parsed_cpis.cpis[0].properties).to eq(cpi_manifest['cpis'][0]['properties'])

        expect(parsed_cpis.cpis[1].name).to eq(cpi_manifest['cpis'][1]['name'])
        expect(parsed_cpis.cpis[1].type).to eq(cpi_manifest['cpis'][1]['type'])
        expect(parsed_cpis.cpis[1].properties).to eq(cpi_manifest['cpis'][1]['properties'])
      end

      it "raises CpiDuplicateName if the cpi name is duplicated" do
        cpi_manifest['cpis'][1]['name'] = cpi_manifest['cpis'][0]['name']
        expect { subject.parse(cpi_manifest) }.to raise_error(Bosh::Director::CpiDuplicateName)
      end
    end
  end
end
