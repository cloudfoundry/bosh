require 'spec_helper'
require 'logger'
require 'bosh/director/models/package'

module Bosh::Director::Models
  describe Template do
    subject!(:template) { FactoryBot.create(:models_template) }

    describe '#find_or_init_from_release_meta' do
      context 'when the template exists' do
        let(:existing_template) do
          Template.find_or_init_from_release_meta(
            release: template.release,
            job_meta: {
              'fingerprint' => template.fingerprint,
              'name' => template.name,
              'sha1' => 'shahahaha',
              'version' => template.version,
            },
            job_manifest: {
              'properties' => { 'park_place' => 'house', 'boardwalk' => 'hotel' },
              'provides' => ['shelter'],
              'consumes' => ['food'],
              'templates' => { 'tem' => 'bowls' },
              'logs' => ['lincoln'],
              'packages' => %w[potato tomato],
            },
          )
        end

        it 'returns the existing template' do
          expect(existing_template.id).to eq(template.id)
        end

        it 'does not create a second one' do
          expect(Template.count).to eq(1)
        end

        it 'sets sha1, logs, package_names, properties, provides, consumes, and spec' do
          expect(existing_template.sha1).to eq('shahahaha')
          expect(existing_template.package_names).to eq(['potato', 'tomato'])
          expect(existing_template.logs).to eq(['lincoln'])

          expect(existing_template.provides).to eq(['shelter'])
          expect(existing_template.consumes).to eq(['food'])
          expect(existing_template.spec).to eq({
            'properties' => {'park_place' => 'house', 'boardwalk' => 'hotel'},
            'provides' => ['shelter'],
            'consumes' => ['food'],
            'templates' => {'tem' => 'bowls'},
            'logs' => ['lincoln'],
            'packages' => ['potato', 'tomato'],
          })
        end
      end

      context 'when the template does not exist' do
        let(:release) { FactoryBot.create(:models_release) }
        let(:new_template) do
          Template.find_or_init_from_release_meta(
            release: release,
            job_meta: {
              'fingerprint' => 'imunique',
              'name' => 'workworkwork',
              'sha1' => 'shahahaha',
              'version' => '3',
            },
            job_manifest: {
              'properties' => { 'park_place' => 'house', 'boardwalk' => 'hotel' },
              'provides' => ['shelter'],
              'consumes' => ['food'],
              'templates' => { 'tem' => 'bowls' },
              'logs' => ['lincoln'],
              'packages' => %w[potato tomato],
            },
          )
        end

        it 'does not write to db' do
          expect(new_template.id).to eq(nil)
          expect(Template.count).to eq(1)
        end

        it 'sets release_id, fingerprint, name, release_id, sha1, version, and spec' do
          expect(new_template.release_id).to eq(release.id)
          expect(new_template.fingerprint).to eq('imunique')
          expect(new_template.name).to eq('workworkwork')
          expect(new_template.sha1).to eq('shahahaha')
          expect(new_template.version).to eq('3')
          expect(new_template.package_names).to eq(['potato','tomato'])
          expect(new_template.logs).to eq(['lincoln'])
          expect(new_template.properties).to eq({'park_place' => 'house', 'boardwalk' => 'hotel'})
          expect(new_template.provides).to eq(['shelter'])
          expect(new_template.consumes).to eq(['food'])
          expect(new_template.spec).to eq({
            'properties' => {'park_place' => 'house', 'boardwalk' => 'hotel'},
            'provides' => ['shelter'],
            'consumes' => ['food'],
            'templates' => {'tem' => 'bowls'},
            'logs' => ['lincoln'],
            'packages' => ['potato', 'tomato'],
          })
        end
      end

      context 'when unknown keys are present in the release_metadata' do
        let(:release) { FactoryBot.create(:models_release) }
        let(:new_template) do
          Template.find_or_init_from_release_meta(
            release: release,
            job_meta: {
              'fingerprint' => 'imunique',
              'name' => 'workworkwork',
              'sha1' => 'shahahaha',
              'version' => '3',
              'unknown' => 'key',
            },
            job_manifest: {},
          )
        end

        it 'ignores them and only uses valid keys' do
          expect(new_template.release_id).to eq(release.id)
          expect(new_template.fingerprint).to eq('imunique')
          expect(new_template.name).to eq('workworkwork')
          expect(new_template.sha1).to eq('shahahaha')
          expect(new_template.version).to eq('3')
          expect(new_template.spec).to eq({})
        end
      end
    end

    describe '#properties' do
      context 'when null' do
        it 'returns empty hash' do
          expect(template.properties).to eq({})
        end
      end

      context 'when not null' do
        before do
          template.spec = {'properties' => {key: 'value'}}
          template.save
        end

        it 'returns object' do
          expect(template.properties).to eq({'key' => 'value'})
        end
      end
    end

    describe '#runs_as_errand?' do
      context 'when templates are null' do
        before { template.spec = {} }

        it 'returns false' do
          expect(template.runs_as_errand?).to eq(false)
        end
      end

      context 'when templates do not contain a mapping to bin/run or bin/run.ps1' do
        before { template.spec = {'templates' => {key: 'value'}} }

        it 'returns false' do
          expect(template.runs_as_errand?).to eq(false)
        end
      end

      context 'when templates contain a mapping to bin/run.ps1' do
        before { template.spec = {'templates' => {'path_key' => 'bin/run.ps1'}} }

        it 'returns false' do
          expect(template.runs_as_errand?).to eq(true)
        end
      end

      context 'when templates contain a mapping to bin/run' do
        before { template.spec = {'templates' => {'path_key' => 'bin/run'}} }

        it 'returns false' do
          expect(template.runs_as_errand?).to eq(true)
        end
      end
    end
  end
end
