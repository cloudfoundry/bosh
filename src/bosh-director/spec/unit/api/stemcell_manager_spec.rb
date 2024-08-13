require 'spec_helper'

module Bosh::Director
  describe Api::StemcellManager do
    let(:username) { 'fake-username' }
    let(:task) { instance_double('Bosh::Director::Models::Task', id: 1) }

    before { allow(JobQueue).to receive(:new).and_return(job_queue) }
    let(:job_queue) { instance_double('Bosh::Director::JobQueue') }

    let(:options) do
      { fake_option: true }
    end

    describe '#create_stemcell_from_url' do
      let(:stemcell_url) { 'http://fake-domain.com/stemcell.tgz' }

      it 'enqueues a task to upload a remote stemcell' do
        expect(job_queue).to receive(:enqueue).with(
          username,
          Jobs::UpdateStemcell,
          'create stemcell',
          [stemcell_url, {fake_option: true, remote: true}],
        ).and_return(task)

        expect(subject.create_stemcell_from_url(username, stemcell_url, options)).to eql(task)
      end

      context 'when a sha1 is provided for the stemcell' do
        let(:options) do
          { sha1: 'shawone' }
        end

        it 'enqueues a task to upload a remote stemcell' do
          expect(job_queue).to receive(:enqueue).with(
            username,
            Jobs::UpdateStemcell,
            'create stemcell',
            [stemcell_url, { remote: true, sha1: 'shawone'}],
          ).and_return(task)

          expect(subject.create_stemcell_from_url(username, stemcell_url, options)).to eql(task)
        end
      end
    end

    describe '#create_stemcell_from_file_path' do
      let(:stemcell_path) { '/path/to/stemcell.tgz' }

      context 'when stemcell file exists' do
        before { allow(File).to receive(:exist?).with(stemcell_path).and_return(true) }

        it 'enqueues a task to upload a remote stemcell' do
          expect(job_queue).to receive(:enqueue).with(
            username,
            Jobs::UpdateStemcell,
            'create stemcell',
            [stemcell_path, {fake_option: true}],
          ).and_return(task)

          expect(subject.create_stemcell_from_file_path(username, stemcell_path, options)).to eql(task)
        end

        context 'when a sha1 is provided for the stemcell' do
          let(:options) do
            { sha1: 'shawone' }
          end

          before { allow(File).to receive(:exist?).with(stemcell_path).and_return(true) }

          it 'enqueues a task to upload a remote stemcell' do
            expect(job_queue).to receive(:enqueue).with(
              username,
              Jobs::UpdateStemcell,
              'create stemcell',
              [stemcell_path, { sha1: 'shawone' }],
            ).and_return(task)

            expect(subject.create_stemcell_from_file_path(username, stemcell_path, options)).to eql(task)
          end
        end
      end

      context 'when stemcell file does not exist' do
        before { allow(File).to receive(:exist?).with(stemcell_path).and_return(false) }

        it 'raises an error' do
          expect(job_queue).to_not receive(:enqueue)

          expect {
            expect(subject.create_stemcell_from_file_path(username, stemcell_path, options))
          }.to raise_error(DirectorError, /Failed to create stemcell: file not found/)
        end
      end
    end

    describe '#all_by_name_and_version' do
      before do
        Bosh::Director::Models::Stemcell.create(
            name: 'my-stemcell-with-a-name',
            version: 'stemcell_version',
            operating_system: 'stemcell_os',
            cid: 'cloud-id-a',
            cpi: 'cpi1'
        )
        Bosh::Director::Models::Stemcell.create(
            name: 'my-stemcell-with-a-name',
            version: 'stemcell_version',
            operating_system: 'stemcell_os',
            cid: 'cloud-id-b',
            cpi: 'cpi2'
        )
        Bosh::Director::Models::Stemcell.create(
            name: 'my-stemcell-with-a-different-name',
            version: 'stemcell_version',
            operating_system: 'stemcell_os',
            cid: 'cloud-id-c',
            cpi: 'cpi3'
        )
      end

      it 'returns all stemcells' do
        stemcells = subject.all_by_name_and_version('my-stemcell-with-a-name', 'stemcell_version')
        expect(stemcells.count).to eq(2)
        expect(stemcells[0].name).to eq('my-stemcell-with-a-name')
        expect(stemcells[0].cpi).to eq('cpi1')
        expect(stemcells[1].name).to eq('my-stemcell-with-a-name')
        expect(stemcells[1].cpi).to eq('cpi2')
        expect(stemcells[1].api_version).to be_nil
      end
    end

    describe '#find_by_name_and_version_and_cpi' do
      let(:cpi_config) do
        { 'cpis' => [{ 'name' => 'cpi1', 'type' => 'cpi' }] }
      end
      before do
        Models::Config.make(:cpi, content: cpi_config.to_yaml)
        Bosh::Director::Models::Stemcell.create(
            name: 'my-stemcell-with-a-name',
            version: 'stemcell_version',
            operating_system: 'stemcell_os',
            cid: 'cloud-id-a',
            cpi: 'cpi1'
        )
      end

      it 'raises an error when the requested stemcell is not found' do
        expect {
          subject.find_by_name_and_version_and_cpi('my-stemcell-with-a-name', 'stemcell_version', 'cpi-notexisting')
        }.to raise_error(RuntimeError, "CPI 'cpi-notexisting' not found in cpi-config")
      end

      it 'returns the uniquely matching stemcell' do
        stemcell = subject.find_by_name_and_version_and_cpi('my-stemcell-with-a-name', 'stemcell_version', 'cpi1')
        expect(stemcell.name).to eq('my-stemcell-with-a-name')
      end

      context 'when a cpi has another alias with the stemcell' do
        let(:migrated_from) do
          { 'cpis' => [{ 'name' => 'cpi2', 'type' => 'cpi', 'migrated_from' => ['name' => 'cpi1'] }] }
        end

        before do
          Models::Config.make(:cpi, content: migrated_from.to_yaml)
        end

        it 'returns the existing stemcell' do
          stemcell = subject.find_by_name_and_version_and_cpi('my-stemcell-with-a-name', 'stemcell_version', 'cpi2')
          expect(stemcell.name).to eq('my-stemcell-with-a-name')
        end
      end
    end

    describe '#all_by_os_and_version' do
      before do
        Bosh::Director::Models::Stemcell.create(
            name: 'my-stemcell-with-a-name-c',
            version: 'stemcell_version',
            operating_system: 'stemcell_os-other',
            cid: 'cloud-id-c',
        )

        Bosh::Director::Models::Stemcell.create(
            name: 'my-stemcell-with-a-name-b',
            version: 'stemcell_version',
            operating_system: 'stemcell_os',
            cid: 'cloud-id-b',
        )

        Bosh::Director::Models::Stemcell.create(
            name: 'my-stemcell-with-a-name-a',
            version: 'stemcell_version',
            operating_system: 'stemcell_os',
            cid: 'cloud-id-a',
        )
      end

      it 'returns all stemcells, sorted alphabetically' do
        stemcells = subject.all_by_os_and_version('stemcell_os', 'stemcell_version')
        expect(stemcells.count).to eq(2)
        expect(stemcells[0].name).to eq('my-stemcell-with-a-name-a')
        expect(stemcells[1].name).to eq('my-stemcell-with-a-name-b')
      end
    end

    describe '#find_all_stemcells' do
      before do
        stemcell1 = FactoryBot.create(:models_stemcell,
          name: 'fake-stemcell-1',
          version: 'stemcell_version-1',
          operating_system: 'stemcell_os-1',
          cid: 'cloud-id-1',
          id: 1,
        )
        stemcell1.add_deployment(FactoryBot.create(:models_deployment, name: 'first'))
        stemcell1.add_deployment(FactoryBot.create(:models_deployment, name: 'second'))
        FactoryBot.create(:models_stemcell,
          name: 'fake-stemcell-3',
          version: 'stemcell_version-3',
          operating_system: 'stemcell_os-3',
          cid: 'cloud-id-3',
          cpi: 'cpi3',
          id: 3,
        )
        FactoryBot.create(:models_stemcell,
          name: 'fake-stemcell-2',
          version: 'stemcell_version-2',
          operating_system: 'stemcell_os-2',
          cid: 'cloud-id-2',
          cpi: 'cpi2',
          api_version: 2,
          id: 2,
        )
      end
      it 'returns a list of all stemcells with the api_version' do
        expect(subject.find_all_stemcells).to eq([
              {
                'name' => 'fake-stemcell-1',
                'operating_system' => 'stemcell_os-1',
                'version' => 'stemcell_version-1',
                'cid' => 'cloud-id-1',
                'cpi' => "",
                'deployments' => [{name: 'first'}, {name: 'second'}],
                'api_version' => nil,
                'id' => 1,
              },
              {
                'name' => 'fake-stemcell-2',
                'operating_system' => 'stemcell_os-2',
                'version' => 'stemcell_version-2',
                'cid' => 'cloud-id-2',
                'cpi' => 'cpi2',
                'deployments' => [],
                'api_version' => 2,
                'id' => 2,
              },
              {
                'name' => 'fake-stemcell-3',
                'operating_system' => 'stemcell_os-3',
                'version' => 'stemcell_version-3',
                'cid' => 'cloud-id-3',
                'cpi' => 'cpi3',
                'deployments' => [],
                'api_version' => nil,
                'id' => 3,
              },
              ])

      end
    end


    describe '#latest_by_name' do
      context 'when there are no version' do

        before {
          Bosh::Director::Models::Stemcell.create(
            name: 'some-other-name',
            version: '10.9-dev',
            operating_system: 'stemcell_os',
            cid: 'cloud-id-b',
          )
        }

        it 'should raise error' do

          expect {
            expect(subject.latest_by_name('my-stemcell-with-b-name'))
          }.to raise_error(StemcellNotFound)
        end
      end


      context 'when there are multiple versions' do
        before {
          Bosh::Director::Models::Stemcell.create(
            name: 'my-stemcell-with-b-name',
            version: '10.9-dev',
            operating_system: 'stemcell_os',
            cid: 'cloud-id-b',
          )

          Bosh::Director::Models::Stemcell.create(
            name: 'my-stemcell-with-b-name',
            version: '1471.2',
            operating_system: 'stemcell_os',
            cid: 'cloud-id-b',
          )

          Bosh::Director::Models::Stemcell.create(
            name: 'my-stemcell-with-b-name',
            version: '1471.2.1',
            operating_system: 'stemcell_os',
            cid: 'cloud-id-b',
          )

          Bosh::Director::Models::Stemcell.create(
            name: 'my-stemcell-with-b-name',
            version: '1471.9',
            operating_system: 'stemcell_os',
            cid: 'cloud-id-b',
          )
        }

        it 'should return the stemcell matching the name with the latest version' do
          stemcell = subject.latest_by_name('my-stemcell-with-b-name')
          expect(stemcell.version).to eq('1471.9')
          expect(stemcell.name).to eq('my-stemcell-with-b-name')
        end

        context 'when a version prefix is supplied' do
          context 'when the version exists' do
            it 'should return the latest version with that prefix' do
              stemcell = subject.latest_by_name('my-stemcell-with-b-name', '1471.2')
              expect(stemcell.version).to eq('1471.2.1')
            end
          end

          context 'when the stemcell exists but there is no version with given prefix' do
            it 'should raise an error' do
              expect {
                subject.latest_by_name('my-stemcell-with-b-name', '1471.3')
              }.to raise_error(
                Bosh::Director::StemcellNotFound,
                "Stemcell 'my-stemcell-with-b-name' exists, but version with prefix '1471.3' not found."
              )
            end
          end
        end
      end
    end

    describe '#latest_by_os' do
      context 'when there are no versions' do
        before {
          Bosh::Director::Models::Stemcell.create(
            name: 'some-other-name',
            version: '10.9-dev',
            operating_system: 'stemcell_os',
            cid: 'cloud-id-b',
          )
        }

        it 'should raise error' do
          expect {
            expect(subject.latest_by_os('stemcell_os_1'))
          }.to raise_error(StemcellNotFound)
        end
      end

      context 'when there are multiple versions' do
        before {
          Bosh::Director::Models::Stemcell.create(
            name: 'my-stemcell-with-b-name',
            version: '10.9-dev',
            operating_system: 'stemcell_os',
            cid: 'cloud-id-b',
          )

          Bosh::Director::Models::Stemcell.create(
            name: 'my-stemcell-with-b-name',
            version: '1471.2',
            operating_system: 'stemcell_os',
            cid: 'cloud-id-b',
          )

          Bosh::Director::Models::Stemcell.create(
            name: 'my-stemcell-with-b-name',
            version: '1471.2.1',
            operating_system: 'stemcell_os',
            cid: 'cloud-id-b',
          )

          Bosh::Director::Models::Stemcell.create(
            name: 'my-stemcell-with-b-name',
            version: '1471.3',
            operating_system: 'stemcell_os',
            cid: 'cloud-id-b',
          )
        }

        context 'when a version prefix is supplied' do
          context 'when the version exists' do
            it 'should return the latest version with that prefix' do
              stemcell = subject.latest_by_os('stemcell_os', '1471.2')
              expect(stemcell.version).to eq('1471.2.1')
            end
          end

          context 'when the stemcell exists but there is no version with given prefix' do
            it 'should raise an error' do
              expect {
                subject.latest_by_os('stemcell_os', '1471.4')
              }.to raise_error(
                Bosh::Director::StemcellNotFound,
                "Stemcell with Operating System 'stemcell_os' exists, but version with prefix '1471.4' not found."
              )
            end
          end
        end

        it 'should return the stemcell matching the name with the latest version' do
          stemcell = subject.latest_by_os('stemcell_os')
          expect(stemcell.version).to eq('1471.3')
          expect(stemcell.operating_system).to eq('stemcell_os')
        end

        it 'should return the stemcell matching the name with the latest version given a prefix' do
          stemcell = subject.latest_by_os('stemcell_os', '1471.3')
          expect(stemcell.version).to eq('1471.3')
          expect(stemcell.operating_system).to eq('stemcell_os')
        end
      end
    end
  end
end
