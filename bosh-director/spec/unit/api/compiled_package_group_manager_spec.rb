require 'spec_helper'

module Bosh::Director
  describe Api::CompiledPackageGroupManager do
    let(:username) { 'fake-username' }
    let(:task) { instance_double('Bosh::Director::Models::Task', id: 1) }

    before { allow(JobQueue).to receive(:new).and_return(job_queue) }
    let(:job_queue) { instance_double('Bosh::Director::JobQueue') }

    describe '#create_from_stream' do
      before do
        allow(SecureRandom).to receive(:uuid).and_return('fake-uuid')
        allow(File).to receive(:exists?).and_return(true)
      end

      let(:compiled_package_group_stream) { double('fake-compiled-package-group-stream', size: 1024) }

      it 'enqueues a task to import a compiled_package_group archive stream' do
        expect(subject).to receive(:check_available_disk_space).
          with(anything, compiled_package_group_stream.size).
          and_return(true)

        tmp_file_path = File.join(Dir.tmpdir, 'compiled-package-group-fake-uuid')
        expect(subject).to receive(:write_file).with(tmp_file_path, compiled_package_group_stream)

        expect(job_queue).to receive(:enqueue).with(
          username,
          Jobs::ImportCompiledPackages,
          'import compiled packages',
          [tmp_file_path],
        ).and_return(task)

        expect(subject.create_from_stream(username, compiled_package_group_stream)).to eql(task)
      end
    end

    describe '#create_from_file_path' do
      let(:compiled_package_group_path) { '/path/to/compiled_package_group.tgz' }

      context 'when compiled_package_group file exists' do
        before { allow(File).to receive(:exists?).with(compiled_package_group_path).and_return(true) }

        it 'enqueues a task to import a local compiled_package_group archive' do
          expect(job_queue).to receive(:enqueue).with(
            username,
            Jobs::ImportCompiledPackages,
            'import compiled packages',
            [compiled_package_group_path],
          ).and_return(task)

          expect(subject.create_from_file_path(username, compiled_package_group_path)).to eql(task)
        end
      end

      context 'when compiled_package_group file does not exist' do
        before { allow(File).to receive(:exists?).with(compiled_package_group_path).and_return(false) }

        it 'raises an error' do
          expect(job_queue).to_not receive(:enqueue)

          expect {
            expect(subject.create_from_file_path(username, compiled_package_group_path))
          }.to raise_error(DirectorError, /Failed to import compiled packages: file not found/)
        end
      end
    end
  end
end
