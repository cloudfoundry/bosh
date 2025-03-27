require 'spec_helper'

describe Bosh::Director::Jobs::UpdateStemcell do
  before do
    allow(Bosh::Director::Config).to receive(:preferred_cpi_api_version).and_return(2)
  end

  describe 'DJ job class expectations' do
    let(:job_type) { :update_stemcell }
    let(:queue) { :normal }
    it_behaves_like 'a DelayedJob job'
  end

  describe '#perform' do
    subject { Bosh::Director::Jobs::UpdateStemcell.new(stemcell_name, stemcell_options) }

    let(:cloud) { instance_double(Bosh::Clouds::ExternalCpi) }
    let(:task) { FactoryBot.create(:models_task, state: 'processing') }
    let(:event_log) { Bosh::Director::EventLog::Log.new }
    let(:event_log_stage) { instance_double(Bosh::Director::EventLog::Stage) }
    let(:verify_multidigest_exit_status) { instance_double(Process::Status, exitstatus: 0) }
    let(:stemcell_uri) { "file://#{stemcell_file.path}" }
    let(:stemcell_name) { stemcell_file.path }
    let(:stemcell_options) { {} }

    let(:manifest) do
      {
        'name' => 'jeos',
        'version' => 5,
        'operating_system' => 'jeos-5',
        'stemcell_formats' => ['dummy'],
        'cloud_properties' => { 'ram' => '2gb' },
        'sha1' => 'FAKE_SHA1',
      }
    end

    let(:stemcell_image_content) { 'FAKE_STEMCELL_IMAGE_CONTENT' }
    let(:stemcell_file) do
      Tempfile.new('stemcell_contents').tap do |tempfile|
        File.write(tempfile.path,
                   gzip(
                     StringIO.new.tap do |io|
                       Minitar::Writer.open(io) do |tar|
                         tar.add_file('stemcell.MF', mode: '0644', mtime: 0) { |os, _| os.write(manifest.to_yaml) }
                         tar.add_file('image', mode: '0644', mtime: 0) { |os, _| os.write(stemcell_image_content) }
                       end
                       io.close
                     end.string
                   ),
        )
      end
    end


    let(:runtime_config_manager) { instance_double(Bosh::Director::Api::RuntimeConfigManager) }
    let(:config) { instance_double(Bosh::Director::Models::Config) }
    let(:runtime_config_list) do
      [config]
    end

    before do

      allow(Bosh::Director::Api::RuntimeConfigManager).to receive(:new).and_return(runtime_config_manager)
      allow(Bosh::Director::Models::Config).to receive(:new).and_return(config)
      allow(config).to receive(:to_hash).and_return({"tags" => {"any"=> "value"}})
      allow(runtime_config_manager).to receive(:list).with(1, 'default').and_return(runtime_config_list)


      allow(Bosh::Director::Config).to receive(:event_log).and_return(event_log)
      allow(Bosh::Director::Config).to receive(:uuid).and_return('meow-uuid')
      allow(Bosh::Director::Config).to receive(:cloud_options).and_return({'provider' => {'path' => '/path/to/default/cpi'}})
      allow(Bosh::Director::Config).to receive(:verify_multidigest_path).and_return('some/path')
      allow(Bosh::Clouds::ExternalCpi).to receive(:new).with('/path/to/default/cpi',
                                                             'meow-uuid',
                                                             instance_of(Logging::Logger),
                                                             stemcell_api_version: nil).and_return(cloud)

      allow(cloud).to receive(:request_cpi_api_version=)
      allow(cloud).to receive(:info).and_return('stemcell_formats' => ['dummy'])

      allow(event_log).to receive(:begin_stage).and_return(event_log_stage)
      allow(event_log_stage).to receive(:advance_and_track).and_yield [nil]
      allow(Open3).to receive(:capture3).and_return([nil, 'some error', verify_multidigest_exit_status])

      allow(Bosh::Director::Config).to receive_message_chain(:current_job, :username).and_return(task.username)
      allow(Bosh::Director::Config).to receive_message_chain(:current_job, :task_id).and_return(task.id)
    end

    after { FileUtils.rm_rf(stemcell_file.path) }

    context 'when the stemcell tarball is valid' do
      context 'uploading a local stemcell' do
        it 'should upload a local stemcell' do
          expect(cloud).to receive(:info).and_return('stemcell_formats' => ['dummy'])
          expect(cloud).to receive(:create_stemcell).with(anything, { 'ram' => '2gb' }) do |image, _|
            contents = File.open(image, &:read)
            expect(contents).to eq(stemcell_image_content)
            'stemcell-cid'
          end

          expected_steps = 5
          expect(event_log).to receive(:begin_stage).with('Update stemcell', expected_steps)
          expect(event_log_stage).to receive(:advance_and_track).exactly(expected_steps).times

          expect(subject).to receive(:with_stemcell_lock).with('jeos', '5', timeout: 900).and_yield
          subject.perform

          stemcell = Bosh::Director::Models::Stemcell.find(name: 'jeos', version: '5')
          expect(stemcell).not_to be_nil
          expect(stemcell.cid).to eq('stemcell-cid')
          expect(stemcell.sha1).to eq('FAKE_SHA1')
          expect(stemcell.operating_system).to eq('jeos-5')
          expect(stemcell.api_version).to be_nil
        end

        context 'when provided an incorrect sha1' do
          let(:verify_multidigest_exit_status) { instance_double(Process::Status, exitstatus: 1) }
          let(:stemcell_name) { stemcell_file.path }
          let(:stemcell_options) { { 'sha1' => 'abcd1234' } }

          it 'fails to upload a stemcell' do
            expect { subject.perform }.to raise_exception(Bosh::Director::StemcellSha1DoesNotMatch)
          end
        end

        context 'when provided a correct sha1' do
          let(:stemcell_name) { stemcell_file.path }
          let(:stemcell_options) { { 'sha1' => 'eeaec4f77e2014966f7f01e949c636b9f9992757' } }

          it 'should upload a local stemcell' do
            expect(cloud).to receive(:info).and_return('stemcell_formats' => ['dummy'])
            expect(cloud).to receive(:create_stemcell).with(anything, { 'ram' => '2gb' }) do |image, _|
              contents = File.open(image, &:read)
              expect(contents).to eq(stemcell_image_content)
              'stemcell-cid'
            end

            expected_steps = 6
            expect(event_log).to receive(:begin_stage).with('Update stemcell', expected_steps)
            expect(event_log_stage).to receive(:advance_and_track).exactly(expected_steps).times

            subject.perform

            stemcell = Bosh::Director::Models::Stemcell.find(name: 'jeos', version: '5')
            expect(stemcell).not_to be_nil
            expect(stemcell.cid).to eq('stemcell-cid')
            expect(stemcell.sha1).to eq('FAKE_SHA1')
            expect(stemcell.operating_system).to eq('jeos-5')
            expect(stemcell.api_version).to be_nil
          end
        end
      end

      context 'uploading a remote stemcell' do
        let(:stemcell_name) { 'fake-stemcell-url' }
        let(:stemcell_options) { { 'remote' => true } }

        it 'should upload a remote stemcell' do
          expect(cloud).to receive(:info).and_return('stemcell_formats' => ['dummy'])
          expect(cloud).to receive(:create_stemcell).with(anything, { 'ram' => '2gb' }) do |image, _|
            contents = File.open(image, &:read)
            expect(contents).to eql(stemcell_image_content)
            'stemcell-cid'
          end

          expected_steps = 6
          expect(event_log).to receive(:begin_stage).with('Update stemcell', expected_steps)
          expect(event_log_stage).to receive(:advance_and_track).exactly(expected_steps).times

          expect(subject).to receive(:download_remote_file) do |resource, url, path|
            expect(resource).to eq('stemcell')
            expect(url).to eq('fake-stemcell-url')
            FileUtils.mv(stemcell_file.path, path)
          end
          subject.perform

          stemcell = Bosh::Director::Models::Stemcell.find(name: 'jeos', version: '5')
          expect(stemcell).not_to be_nil
          expect(stemcell.cid).to eq('stemcell-cid')
          expect(stemcell.sha1).to eq('FAKE_SHA1')
          expect(stemcell.api_version).to be_nil
        end

        context 'when provided an incorrect sha1' do
          let(:verify_multidigest_exit_status) { instance_double(Process::Status, exitstatus: 1) }
          let(:stemcell_name) { 'fake-stemcell-url' }
          let(:stemcell_options) do
            {
              'remote' => true,
              'sha1' => 'abcd1234',
            }
          end

          it 'fails to upload a stemcell' do
            expect(subject).to receive(:download_remote_file) do |resource, url, path|
              expect(resource).to eq('stemcell')
              expect(url).to eq('fake-stemcell-url')
              FileUtils.mv(stemcell_file.path, path)
            end

            expect { subject.perform }.to raise_exception(Bosh::Director::StemcellSha1DoesNotMatch)
          end
        end

        context 'when provided a correct sha1' do
          let(:stemcell_name) { 'fake-stemcell-url' }
          let(:stemcell_options) do
            {
              'remote' => true,
              'sha1' => 'abcd1234',
            }
          end

          it 'should upload a remote stemcell' do
            expect(cloud).to receive(:info).and_return('stemcell_formats' => ['dummy'])
            expect(cloud).to receive(:create_stemcell).with(anything, { 'ram' => '2gb' }) do |image, _|
              contents = File.open(image, &:read)
              expect(contents).to eql(stemcell_image_content)
              'stemcell-cid'
            end

            expected_steps = 7
            expect(event_log).to receive(:begin_stage).with('Update stemcell', expected_steps)
            expect(event_log_stage).to receive(:advance_and_track).exactly(expected_steps).times

            expect(subject).to receive(:download_remote_file) do |resource, url, path|
              expect(resource).to eq('stemcell')
              expect(url).to eq('fake-stemcell-url')
              FileUtils.mv(stemcell_file.path, path)
            end
            subject.perform

            stemcell = Bosh::Director::Models::Stemcell.find(name: 'jeos', version: '5')
            expect(stemcell).not_to be_nil
            expect(stemcell.cid).to eq('stemcell-cid')
            expect(stemcell.sha1).to eq('FAKE_SHA1')
            expect(stemcell.api_version).to be_nil
          end
        end
      end

      it 'should cleanup the stemcell file' do
        expect(cloud).to receive(:info).and_return('stemcell_formats' => ['dummy'])
        expect(cloud).to receive(:create_stemcell).with(anything, { 'ram' => '2gb' }) do |image, _|
          contents = File.open(image, &:read)
          expect(contents).to eql(stemcell_image_content)
          'stemcell-cid'
        end

        subject.perform

        expect(File.exist?(stemcell_file.path)).to be(false)
      end

      context 'when stemcell already exists' do
        before do
          FactoryBot.create(:models_stemcell, name: 'jeos', version: '5', cid: 'old-stemcell-cid')
        end

        it 'should quietly ignore duplicate upload and not create a stemcell in the cloud' do
          expect(cloud).to receive(:info).and_return('stemcell_formats' => ['dummy'])
          expected_steps = 5
          expect(event_log).to receive(:begin_stage).with('Update stemcell', expected_steps)
          expect(event_log_stage).to receive(:advance_and_track).exactly(expected_steps).times

          expect(subject.perform).to eq('/stemcells/jeos/5')
        end

        context "when upload stemcell option 'remote' is true" do
          let(:stemcell_options) { { 'remote' => true } }

          it 'should quietly ignore duplicate remote uploads and not create a stemcell in the cloud' do
            expected_steps = 6
            expect(cloud).to receive(:info).and_return('stemcell_formats' => ['dummy'])
            expect(event_log).to receive(:begin_stage).with('Update stemcell', expected_steps)
            expect(event_log_stage).to receive(:advance_and_track).exactly(expected_steps).times

            expect(subject).to receive(:download_remote_file) do |_, remote_file, local_file|
              uri = URI.parse(remote_file)
              FileUtils.cp(uri.path, local_file)
            end
            expect(subject.perform).to eq('/stemcells/jeos/5')
          end
        end

        context "when upload stemcell option 'fix' is true" do
          let(:stemcell_options) { { 'fix' => true } }

          it 'should upload stemcell and update db with --fix option set' do
            expect(cloud).to receive(:info).and_return('stemcell_formats' => ['dummy'])
            expect(cloud).to receive(:create_stemcell).and_return 'new-stemcell-cid'
            expected_steps = 5
            expect(event_log).to receive(:begin_stage).with('Update stemcell', expected_steps)
            expect(event_log_stage).to receive(:advance_and_track).exactly(expected_steps).times

            expect { subject.perform }.to_not raise_error

            stemcell = Bosh::Director::Models::Stemcell.find(name: 'jeos', version: '5')
            expect(stemcell).not_to be_nil
            expect(stemcell.cid).to eq('new-stemcell-cid')
          end
        end
      end

      it 'should fail if cannot extract stemcell' do
        result = Bosh::Common::Exec::Result.new('cmd', 'output', 1)
        expect(Bosh::Common::Exec).to receive(:sh).and_return(result)

        expect do
          subject.perform
        end.to raise_exception(Bosh::Director::StemcellInvalidArchive)
      end

      context 'when having multiple cpis' do
        let(:cloud_factory) { instance_double(Bosh::Director::CloudFactory) }
        let(:cloud1) { cloud }
        let(:cloud2) { cloud }
        let(:cloud3) { cloud }

        before do
          allow(Bosh::Director::CloudFactory).to receive(:create).and_return(cloud_factory)
          allow(cloud_factory).to receive(:get_cpi_aliases).with('cloud1').and_return(['cloud1'])
          allow(cloud_factory).to receive(:get_cpi_aliases).with('cloud2').and_return(['cloud2'])
          allow(cloud_factory).to receive(:get_cpi_aliases).with('cloud3').and_return(['cloud3'])
        end

        it 'creates multiple stemcell records with different cpi attributes' do
          expect(cloud1).to receive(:create_stemcell).with(anything, { 'ram' => '2gb' }).and_return('stemcell-cid1')
          expect(cloud3).to receive(:create_stemcell).with(anything, { 'ram' => '2gb' }).and_return('stemcell-cid3')

          expect(cloud1).to receive(:info).and_return('stemcell_formats' => ['dummy'])
          expect(cloud2).to receive(:info).and_return('stemcell_formats' => ['dummy1'])
          expect(cloud3).to receive(:info).and_return('stemcell_formats' => ['dummy'])

          expect(cloud_factory).to receive(:all_names).exactly(3).times.and_return(%w[cloud1 cloud2 cloud3])
          expect(cloud_factory).to receive(:get).with('cloud1').and_return(Bosh::Clouds::ExternalCpiResponseWrapper.new(cloud1, 1))
          expect(cloud_factory).to receive(:get).with('cloud2').and_return(Bosh::Clouds::ExternalCpiResponseWrapper.new(cloud2, 1))
          expect(cloud_factory).to receive(:get).with('cloud3').and_return(Bosh::Clouds::ExternalCpiResponseWrapper.new(cloud3, 1))

          expected_steps = 11
          expect(event_log).to receive(:begin_stage).with('Update stemcell', expected_steps)

          step_messages = [
            'Checking if this stemcell already exists (cpi: cloud1)',
            'Checking if this stemcell already exists (cpi: cloud3)',
            'Uploading stemcell jeos/5 to the cloud (cpi: cloud1)',
            'Uploading stemcell jeos/5 to the cloud (cpi: cloud3)',
            'Save stemcell jeos/5 (stemcell-cid1) (cpi: cloud1)',
            'Save stemcell jeos/5 (stemcell-cid3) (cpi: cloud3)',
          ]

          step_messages.each do |msg|
            expect(event_log_stage).to receive(:advance_and_track).with(msg)
          end
          # seems that rspec already subtracts the expected messages above, so we have to subtract them from the expected overall count
          expect(event_log_stage).to receive(:advance_and_track).exactly(expected_steps - step_messages.count - 3).times

          expect(subject).to receive(:with_stemcell_lock).with('jeos', '5', timeout: 900 * 3).and_yield

          subject.perform

          stemcells = Bosh::Director::Models::Stemcell.where(name: 'jeos', version: '5').order(:name).all

          expect(stemcells.count).to eq(2)
          expect(stemcells[0]).not_to be_nil
          expect(stemcells[0].sha1).to eq('FAKE_SHA1')
          expect(stemcells[0].operating_system).to eq('jeos-5')
          expect(stemcells[0].cpi).to eq('cloud1')
          expect(stemcells[0].cid).to eq('stemcell-cid1')
          expect(stemcells[0].api_version).to be_nil

          expect(stemcells[1]).not_to be_nil
          expect(stemcells[1].sha1).to eq('FAKE_SHA1')
          expect(stemcells[1].operating_system).to eq('jeos-5')
          expect(stemcells[1].cpi).to eq('cloud3')
          expect(stemcells[1].cid).to eq('stemcell-cid3')
          expect(stemcells[1].api_version).to be_nil

          stemcell_uploads = Bosh::Director::Models::StemcellUpload.where(name: 'jeos', version: '5').all
          expect(stemcell_uploads.map(&:cpi)).to contain_exactly('cloud1', 'cloud2', 'cloud3')
        end

        it 'skips creating a stemcell match when a CPI fails' do
          expect(cloud1).to receive(:create_stemcell).with(anything, { 'ram' => '2gb' }).and_raise('I am flaky')
          expect(cloud1).to receive(:info).and_return('stemcell_formats' => ['dummy'])
          expect(cloud_factory).to receive(:get).with('cloud1').and_return(Bosh::Clouds::ExternalCpiResponseWrapper.new(cloud1, 1))
          expect(cloud_factory).to receive(:all_names).exactly(3).times.and_return(['cloud1'])

          expect { subject.perform }.to raise_error 'I am flaky'

          expect(Bosh::Director::Models::StemcellUpload.all.count).to eq(0)
        end

        context 'when the stemcell has already been uploaded' do
          before do
            FactoryBot.create(:models_stemcell, name: 'jeos', version: '5', cpi: 'cloud1')
            FactoryBot.create(:models_stemcell_upload, name: 'jeos', version: '5', cpi: 'cloud2')
          end

          it 'creates one stemcell and one stemcell match per cpi' do
            expect(cloud_factory).to receive(:all_names).exactly(3).times.and_return(%w[cloud1 cloud2 cloud3])
            expect(cloud_factory).to receive(:get).with('cloud1').and_return(Bosh::Clouds::ExternalCpiResponseWrapper.new(cloud1, 1))
            expect(cloud_factory).to receive(:get).with('cloud2').and_return(Bosh::Clouds::ExternalCpiResponseWrapper.new(cloud2, 1))
            expect(cloud_factory).to receive(:get).with('cloud3').and_return(Bosh::Clouds::ExternalCpiResponseWrapper.new(cloud3, 1))

            expect(cloud1).to receive(:info).and_return('stemcell_formats' => ['dummy'])
            expect(cloud2).to receive(:info).and_return('stemcell_formats' => ['dummy1'])
            expect(cloud3).to receive(:info).and_return('stemcell_formats' => ['dummy'])

            expect(cloud3).to receive(:create_stemcell).with(anything, { 'ram' => '2gb' }).and_return('stemcell-cid3')

            expect(Bosh::Director::Models::Stemcell.all.count).to eq(1)
            expect(Bosh::Director::Models::StemcellUpload.all.count).to eq(1)

            subject.perform

            expect(Bosh::Director::Models::Stemcell.all.map do |s|
              { name: s.name, version: s.version, cpi: s.cpi }
            end).to contain_exactly(
              { name: 'jeos', version: '5', cpi: 'cloud1' },
              { name: 'jeos', version: '5', cpi: 'cloud3' },
            )

            expect(Bosh::Director::Models::StemcellUpload.all.map do |s|
              { name: s.name, version: s.version, cpi: s.cpi }
            end).to contain_exactly(
              { name: 'jeos', version: '5', cpi: 'cloud1' },
              { name: 'jeos', version: '5', cpi: 'cloud2' },
              { name: 'jeos', version: '5', cpi: 'cloud3' },
            )
          end
        end

        it 'still works with the default cpi' do
          expect(cloud).to receive(:info).and_return('stemcell_formats' => ['dummy'])
          expect(cloud).to receive(:create_stemcell).with(anything, { 'ram' => '2gb' }).and_return('stemcell-cid')

          expect(cloud_factory).to receive(:get_cpi_aliases).with('').and_return([''])
          expect(cloud_factory).to receive(:all_names).exactly(3).times.and_return([''])
          expect(cloud_factory).to receive(:get).with('').and_return(Bosh::Clouds::ExternalCpiResponseWrapper.new(cloud, 1))

          expected_steps = 5
          expect(event_log).to receive(:begin_stage).with('Update stemcell', expected_steps)
          expect(event_log_stage).to receive(:advance_and_track).with('Checking if this stemcell already exists')
          expect(event_log_stage).to receive(:advance_and_track).with('Uploading stemcell jeos/5 to the cloud')
          expect(event_log_stage).to receive(:advance_and_track).with('Save stemcell jeos/5 (stemcell-cid)')
          # seems that rspec already subtracts the expected messages above, so we have to subtract them from the expected overall count
          expect(event_log_stage).to receive(:advance_and_track).exactly(expected_steps - 3).times

          subject.perform

          stemcells = Bosh::Director::Models::Stemcell.where(name: 'jeos', version: '5').all

          expect(stemcells.count).to eq(1)
          expect(stemcells[0]).not_to be_nil
          expect(stemcells[0].sha1).to eq('FAKE_SHA1')
          expect(stemcells[0].operating_system).to eq('jeos-5')
          expect(stemcells[0].cpi).to eq('')
          expect(stemcells[0].api_version).to be_nil
        end
      end
    end

    context 'when information about stemcell formats is not enough' do
      let(:manifest) do
        {
          'name' => 'jeos',
          'version' => 5,
          'cloud_properties' => { 'ram' => '2gb' },
          'sha1' => 'FAKE_SHA1',
        }
      end

      context 'when stemcell does not have stemcell formats' do
        it 'should not fail' do
          expect(cloud).to receive(:info).and_return('stemcell_formats' => ['dummy'])
          expect(cloud).to receive(:create_stemcell).with(anything, { 'ram' => '2gb' }) do |image, _|
            contents = File.open(image, &:read)
            expect(contents).to eql(stemcell_image_content)
            'stemcell-cid'
          end

          expect { subject.perform }.not_to raise_error
        end
      end

      context 'when cpi does not have stemcell formats' do
        let(:manifest) do
          {
            'name' => 'jeos',
            'version' => 5,
            'cloud_properties' => { 'ram' => '2gb' },
            'sha1' => 'FAKE_SHA1',
          }
        end

        it 'should not fail' do
          expect(cloud).to receive(:info).and_return({})
          expect(cloud).to receive(:create_stemcell).with(anything, { 'ram' => '2gb' }) do |image, _|
            contents = File.open(image, &:read)
            expect(contents).to eql(stemcell_image_content)
            'stemcell-cid'
          end

          expect { subject.perform }.not_to raise_error
        end
      end

      context 'when cpi does not support stemcell formats' do
        let(:manifest) do
          {
            'name' => 'jeos',
            'version' => 5,
            'cloud_properties' => { 'ram' => '2gb' },
            'sha1' => 'FAKE_SHA1',
          }
        end

        it 'should not fail' do
          expect(cloud).to receive(:info).and_raise(Bosh::Clouds::NotImplemented)
          expect(cloud).to receive(:create_stemcell).with(anything, { 'ram' => '2gb' }) do |image, _|
            contents = File.open(image, &:read)
            expect(contents).to eql(stemcell_image_content)
            'stemcell-cid'
          end

          expect { subject.perform }.not_to raise_error
        end
      end
    end

    context 'when the stemcell metadata lacks a value for operating_system' do
      let(:manifest) do
        {
          'name' => 'jeos',
          'version' => 5,
          'cloud_properties' => { 'ram' => '2gb' },
          'sha1' => 'FAKE_SHA1',
        }
      end

      it 'should not fail' do
        expect(cloud).to receive(:info).and_return('stemcell_formats' => ['dummy'])
        expect(cloud).to receive(:create_stemcell).with(anything, { 'ram' => '2gb' }) do |image, _|
          contents = File.open(image, &:read)
          expect(contents).to eql(stemcell_image_content)
          'stemcell-cid'
        end

        expect { subject.perform }.not_to raise_error
      end
    end

    context 'when api_version is provided' do
      let(:stemcell_options) { { 'sha1' => 'eeaec4f77e2014966f7f01e949c636b9f9992757' } }
      let(:manifest) do
        {
          'name' => 'jeos',
          'version' => 5,
          'operating_system' => 'jeos-5',
          'stemcell_formats' => ['dummy'],
          'cloud_properties' => { 'ram' => '2gb' },
          'sha1' => 'FAKE_SHA1',
          'api_version' => 2,
        }
      end

      it 'should update api_version' do
        expect(cloud).to receive(:info).and_return('stemcell_formats' => ['dummy'])
        expect(cloud).to receive(:create_stemcell).with(anything, { 'ram' => '2gb' }) do |image, _|
          contents = File.open(image, &:read)
          expect(contents).to eq(stemcell_image_content)
          'stemcell-cid'
        end

        subject.perform

        stemcell = Bosh::Director::Models::Stemcell.find(name: 'jeos', version: '5')
        expect(stemcell).not_to be_nil
        expect(stemcell.cid).to eq('stemcell-cid')
        expect(stemcell.sha1).to eq('FAKE_SHA1')
        expect(stemcell.operating_system).to eq('jeos-5')
        expect(stemcell.api_version).to eq(2)
      end
    end
  end
end
