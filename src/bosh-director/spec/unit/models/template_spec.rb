require 'spec_helper'
require 'logger'
require 'bosh/director/models/package'

module Bosh::Director::Models
  describe Template do
    subject(:template) { described_class.make }

    describe '#properties' do

      context 'when null' do
        it 'returns empty hash' do
          expect(template.properties).to eq({})
        end
      end

      context 'when not null' do
        before do
          template.properties = {key: 'value'}
          template.save
        end

        it 'returns object' do
          expect(template.properties).to eq( { 'key' => 'value'} )
        end
      end
    end

    describe '#templates' do
      context 'when null' do
        it 'returns nil' do
          expect(template.templates).to eq(nil)
        end
      end

      context 'when not null' do
        before do
          template.templates = {key: 'value'}
          template.save
        end

        it 'returns object' do
          expect(template.templates).to eq( { 'key' => 'value'} )
        end
      end
    end

    describe '#runs_as_errand?' do
      context 'when templates are null' do
        it 'returns false' do
          template.templates = nil
          expect(template.runs_as_errand?).to eq(false)
        end
      end

      context 'when templates do not contain a mapping to bin/run or bin/run.ps1' do
        it 'returns false' do
          template.templates = {key: 'value'}
          expect(template.runs_as_errand?).to eq(false)
        end
      end

      context 'when templates contain a mapping to bin/run.ps1' do
        it 'returns false' do
          template.templates = {'path_key' => 'bin/run.ps1'}
          expect(template.runs_as_errand?).to eq(true)
        end
      end

      context 'when templates contain a mapping to bin/run' do
        it 'returns false' do
          template.templates = {'thing' => 'bin/run'}
          expect(template.runs_as_errand?).to eq(true)
        end
      end
    end
  end
end

