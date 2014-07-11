require 'spec_helper'

module Bosh::Director
  describe Api::CompiledPackageGroupManager do
    let(:username) { 'fake-username' }
    let(:task) { instance_double('Bosh::Director::Models::Task', id: 1) }

    before { allow(JobQueue).to receive(:new).and_return(job_queue) }
    let(:job_queue) { instance_double('Bosh::Director::JobQueue') }

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
