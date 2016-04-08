require 'spec_helper'

module Bosh::Director
  describe Api::StemcellManager do
    let(:username) { 'fake-username' }
    let(:task) { instance_double('Bosh::Director::Models::Task', id: 1) }

    before { allow(JobQueue).to receive(:new).and_return(job_queue) }
    let(:job_queue) { instance_double('Bosh::Director::JobQueue') }

    let(:options) {{fake_option: true}}

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
        let(:options) {
          {sha1: 'shawone'}
        }

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
        before { allow(File).to receive(:exists?).with(stemcell_path).and_return(true) }

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
          let(:options) {
            {sha1: 'shawone'}
          }

          before { allow(File).to receive(:exists?).with(stemcell_path).and_return(true) }

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
        before { allow(File).to receive(:exists?).with(stemcell_path).and_return(false) }

        it 'raises an error' do
          expect(job_queue).to_not receive(:enqueue)

          expect {
            expect(subject.create_stemcell_from_file_path(username, stemcell_path, options))
          }.to raise_error(DirectorError, /Failed to create stemcell: file not found/)
        end
      end
    end

    describe '#find_by_os_and_version' do
      before do
        Bosh::Director::Models::Stemcell.create(
          name: 'my-stemcell-with-a-name',
          version: 'stemcell_version',
          operating_system: 'stemcell_os',
          cid: 'cloud-id-a',
        )
      end

      it 'raises an error when the requested stemcell is not found' do
        expect {
          subject.find_by_os_and_version('CBM BASIC V2', '1')
        }.to raise_error(Bosh::Director::StemcellNotFound)
      end

      it 'returns the uniquely matching stemcell' do
        stemcell = subject.find_by_os_and_version('stemcell_os', 'stemcell_version')
        expect(stemcell.name).to eq('my-stemcell-with-a-name')
      end

      context 'when there are multiple matches for the requested OS and version' do
        before {
          Bosh::Director::Models::Stemcell.create(
              name: 'my-stemcell-with-b-name',
              version: 'stemcell_version',
              operating_system: 'stemcell_os',
              cid: 'cloud-id-b',
          )
        }

        it 'chooses the first stemcell alhpabetically by name' do
          stemcell = subject.find_by_os_and_version('stemcell_os', 'stemcell_version')
          expect(stemcell.name).to eq('my-stemcell-with-a-name')
        end
      end
    end

    describe '#find_all_stemcells' do
      before do
          stemcell_1 = Bosh::Director::Models::Stemcell.create(
            name: 'fake-stemcell-1',
            version: 'stemcell_version-1',
            operating_system: 'stemcell_os-1',
            cid: 'cloud-id-1',
          )
          stemcell_1.add_deployment(Models::Deployment.make(name: 'first'))
          stemcell_1.add_deployment(Models::Deployment.make(name: 'second'))
          Bosh::Director::Models::Stemcell.create(
            name: 'fake-stemcell-3',
            version: 'stemcell_version-3',
            operating_system: 'stemcell_os-3',
            cid: 'cloud-id-3',
          )
          Bosh::Director::Models::Stemcell.create(
            name: 'fake-stemcell-2',
            version: 'stemcell_version-2',
            operating_system: 'stemcell_os-2',
            :cid => 'cloud-id-2',
          )
      end
      it 'returns a list of all stemcells' do
        expect(subject.find_all_stemcells).to eq([
              {
                'name' => 'fake-stemcell-1',
                'operating_system' => 'stemcell_os-1',
                'version' => 'stemcell_version-1',
                'cid' => 'cloud-id-1',
                'deployments' => [{name: 'first'}, {name: 'second'}]
              },
              {
                'name' => 'fake-stemcell-2',
                'operating_system' => 'stemcell_os-2',
                'version' => 'stemcell_version-2',
                'cid' => 'cloud-id-2',
                'deployments' => []
              },
              {
                'name' => 'fake-stemcell-3',
                'operating_system' => 'stemcell_os-3',
                'version' => 'stemcell_version-3',
                'cid' => 'cloud-id-3',
                'deployments' => []
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
            expect(subject.latest_by_name ('my-stemcell-with-b-name'))
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
            version: '1471_2',
            operating_system: 'stemcell_os',
            cid: 'cloud-id-b',
          )
        }
        it 'should return the stemcell matching the name with the latest version' do
          stemcell = subject.latest_by_name ('my-stemcell-with-b-name')
          expect(stemcell.version).to eq ('1471_2')
          expect(stemcell.name).to eq('my-stemcell-with-b-name')
        end
      end
    end

    describe '#latest_by_os' do
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
            expect(subject.latest_by_os ('stemcell_os_1'))
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
            version: '1471_2',
            operating_system: 'stemcell_os',
            cid: 'cloud-id-b',
          )
        }
        it 'should return the stemcell matching the name with the latest version' do
          stemcell = subject.latest_by_os ('stemcell_os')
          expect(stemcell.version).to eq ('1471_2')
          expect(stemcell.operating_system).to eq('stemcell_os')
        end
      end
    end
  end
end
