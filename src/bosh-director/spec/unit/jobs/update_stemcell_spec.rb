require 'spec_helper'
require 'net/http'

describe Bosh::Director::Jobs::UpdateStemcell do
  describe 'DJ job class expectations' do
    let(:job_type) { :update_stemcell }
    let(:queue) { :normal }
    it_behaves_like 'a DJ job'
  end

  describe '#perform' do
    let(:cloud) { Bosh::Director::Config.cloud }

    let(:event_log){ Bosh::Director::EventLog::Log.new }
    let(:event_log_stage){instance_double(Bosh::Director::EventLog::Stage)}
    let(:verify_multidigest_exit_status) { instance_double(Process::Status, exitstatus: 0)}

    before do
      allow(Bosh::Director::Config).to receive(:event_log).and_return(event_log)
      allow(event_log).to receive(:begin_stage).and_return(event_log_stage)
      allow(event_log_stage).to receive(:advance_and_track).and_yield [nil]
      allow(Bosh::Director::Config).to receive(:verify_multidigest_path).and_return('some/path')
      allow(Open3).to receive(:capture3).and_return([nil, 'some error', verify_multidigest_exit_status])
    end

    context 'when the stemcell tarball is valid' do
      before do
        manifest = {
            "name" => "jeos",
            "version" => 5,
            "operating_system" => "jeos-5",
            "stemcell_formats" => ["dummy"],
            "cloud_properties" => {"ram" => "2gb"},
            "sha1" => "shawone"
        }
        stemcell_contents = create_stemcell(manifest, "image contents")
        @stemcell_file = Tempfile.new("stemcell_contents")
        File.open(@stemcell_file.path, "w") { |f| f.write(stemcell_contents) }
        @stemcell_url = "file://#{@stemcell_file.path}"
      end
      after { FileUtils.rm_rf(@stemcell_file.path) }

      context 'uploading a local stemcell' do
        it "should upload a local stemcell" do
          expect(cloud).to receive(:info).and_return({"stemcell_formats" => ["dummy"]})
          expect(cloud).to receive(:create_stemcell).with(anything, {"ram" => "2gb"}) do |image, _|
            contents = File.open(image) { |f| f.read }
            expect(contents).to eq("image contents")
            "stemcell-cid"
          end

          expected_steps = 5
          expect(event_log).to receive(:begin_stage).with('Update stemcell', expected_steps)
          expect(event_log_stage).to receive(:advance_and_track).exactly(expected_steps).times

          update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(@stemcell_file.path)
          update_stemcell_job.perform

          stemcell = Bosh::Director::Models::Stemcell.find(:name => "jeos", :version => "5")
          expect(stemcell).not_to be_nil
          expect(stemcell.cid).to eq("stemcell-cid")
          expect(stemcell.sha1).to eq("shawone")
          expect(stemcell.operating_system).to eq("jeos-5")
        end

        context 'when provided an incorrect sha1' do
          let(:verify_multidigest_exit_status) { instance_double(Process::Status, exitstatus: 1)}

          it "fails to upload a stemcell" do
            update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(@stemcell_file.path, { 'sha1' => 'abcd1234' })
            expect { update_stemcell_job.perform }.to raise_exception(Bosh::Director::StemcellSha1DoesNotMatch)
          end
        end

        context 'when provided a correct sha1' do
          it "should upload a local stemcell" do
            expect(cloud).to receive(:info).and_return({"stemcell_formats" => ["dummy"]})
            expect(cloud).to receive(:create_stemcell).with(anything, {"ram" => "2gb"}) do |image, _|
              contents = File.open(image) { |f| f.read }
              expect(contents).to eq("image contents")
              "stemcell-cid"
            end

            expected_steps = 6
            expect(event_log).to receive(:begin_stage).with('Update stemcell', expected_steps)
            expect(event_log_stage).to receive(:advance_and_track).exactly(expected_steps).times

            update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(@stemcell_file.path, { 'sha1' => 'eeaec4f77e2014966f7f01e949c636b9f9992757' })
            update_stemcell_job.perform

            stemcell = Bosh::Director::Models::Stemcell.find(:name => "jeos", :version => "5")
            expect(stemcell).not_to be_nil
            expect(stemcell.cid).to eq("stemcell-cid")
            expect(stemcell.sha1).to eq("shawone")
            expect(stemcell.operating_system).to eq("jeos-5")
          end
        end
      end

      context 'uploading a remote stemcell' do
        it "should upload a remote stemcell" do
          expect(cloud).to receive(:info).and_return({"stemcell_formats" => ["dummy"]})
          expect(cloud).to receive(:create_stemcell).with(anything, {"ram" => "2gb"}) do |image, _|
            contents = File.open(image) { |f| f.read }
            expect(contents).to eql("image contents")
            "stemcell-cid"
          end

          expected_steps = 6
          expect(event_log).to receive(:begin_stage).with('Update stemcell', expected_steps)
          expect(event_log_stage).to receive(:advance_and_track).exactly(expected_steps).times

          update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new('fake-stemcell-url', {'remote' => true})
          expect(update_stemcell_job).to receive(:download_remote_file) do |resource, url, path|
            expect(resource).to eq('stemcell')
            expect(url).to eq('fake-stemcell-url')
            FileUtils.mv(@stemcell_file.path, path)
          end
          update_stemcell_job.perform

          stemcell = Bosh::Director::Models::Stemcell.find(:name => "jeos", :version => "5")
          expect(stemcell).not_to be_nil
          expect(stemcell.cid).to eq("stemcell-cid")
          expect(stemcell.sha1).to eq("shawone")
        end

        context 'when provided an incorrect sha1' do
          let(:verify_multidigest_exit_status) { instance_double(Process::Status, exitstatus: 1)}

          it "fails to upload a stemcell" do
            update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new('fake-stemcell-url', {'remote' => true, 'sha1' => 'abcd1234'})
            expect(update_stemcell_job).to receive(:download_remote_file) do |resource, url, path|
              expect(resource).to eq('stemcell')
              expect(url).to eq('fake-stemcell-url')
              FileUtils.mv(@stemcell_file.path, path)
            end

            expect { update_stemcell_job.perform }.to raise_exception(Bosh::Director::StemcellSha1DoesNotMatch)
          end
        end

        context 'when provided a correct sha1' do
          it "should upload a remote stemcell" do
            expect(cloud).to receive(:info).and_return({"stemcell_formats" => ["dummy"]})
            expect(cloud).to receive(:create_stemcell).with(anything, {"ram" => "2gb"}) do |image, _|
              contents = File.open(image) { |f| f.read }
              expect(contents).to eql("image contents")
              "stemcell-cid"
            end

            expected_steps = 7
            expect(event_log).to receive(:begin_stage).with('Update stemcell', expected_steps)
            expect(event_log_stage).to receive(:advance_and_track).exactly(expected_steps).times

            update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new('fake-stemcell-url', {'remote' => true, 'sha1' => 'eeaec4f77e2014966f7f01e949c636b9f9992757'})
            expect(update_stemcell_job).to receive(:download_remote_file) do |resource, url, path|
              expect(resource).to eq('stemcell')
              expect(url).to eq('fake-stemcell-url')
              FileUtils.mv(@stemcell_file.path, path)
            end
            update_stemcell_job.perform

            stemcell = Bosh::Director::Models::Stemcell.find(:name => "jeos", :version => "5")
            expect(stemcell).not_to be_nil
            expect(stemcell.cid).to eq("stemcell-cid")
            expect(stemcell.sha1).to eq("shawone")
          end
        end
      end

      it "should cleanup the stemcell file" do
        expect(cloud).to receive(:info).and_return({"stemcell_formats" => ["dummy"]})
        expect(cloud).to receive(:create_stemcell).with(anything, {"ram" => "2gb"}) do |image, _|
          contents = File.open(image) { |f| f.read }
          expect(contents).to eql("image contents")
          "stemcell-cid"
        end

        update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(@stemcell_file.path)
        update_stemcell_job.perform

        expect(File.exist?(@stemcell_file.path)).to be(false)
      end

      context 'when stemcell already exists' do
        before do
          Bosh::Director::Models::Stemcell.make(:name => "jeos", :version => "5", :cid=>"old-stemcell-cid")
        end

        it "should quietly ignore duplicate upload and not create a stemcell in the cloud" do
          expect(cloud).to receive(:info).and_return({"stemcell_formats" => ["dummy"]})
          expected_steps = 5
          expect(event_log).to receive(:begin_stage).with('Update stemcell', expected_steps)
          expect(event_log_stage).to receive(:advance_and_track).exactly(expected_steps).times

          update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(@stemcell_file.path)
          expect(update_stemcell_job.perform).to eq('/stemcells/jeos/5')
        end

        it "should quietly ignore duplicate remote uploads and not create a stemcell in the cloud" do
          expected_steps = 6
          expect(cloud).to receive(:info).and_return({"stemcell_formats" => ["dummy"]})
          expect(event_log).to receive(:begin_stage).with('Update stemcell', expected_steps)
          expect(event_log_stage).to receive(:advance_and_track).exactly(expected_steps).times

          update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(@stemcell_url, {'remote' => true})
          expect(update_stemcell_job).to receive(:download_remote_file) do |_, remote_file, local_file|
            uri = URI.parse(remote_file)
            FileUtils.cp(uri.path, local_file)
          end
          expect(update_stemcell_job.perform).to eq('/stemcells/jeos/5')
        end

        it 'should upload stemcell and update db with --fix option set' do
          expect(cloud).to receive(:info).and_return({"stemcell_formats" => ["dummy"]})
          expect(cloud).to receive(:create_stemcell).and_return "new-stemcell-cid"
          expected_steps = 5
          expect(event_log).to receive(:begin_stage).with('Update stemcell', expected_steps)
          expect(event_log_stage).to receive(:advance_and_track).exactly(expected_steps).times

          update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(@stemcell_file.path, 'fix' => true)
          expect { update_stemcell_job.perform }.to_not raise_error

          stemcell = Bosh::Director::Models::Stemcell.find(:name => "jeos", :version => "5")
          expect(stemcell).not_to be_nil
          expect(stemcell.cid).to eq("new-stemcell-cid")
        end
      end

      it "should fail if cannot extract stemcell" do
        result = Bosh::Exec::Result.new("cmd", "output", 1)
        expect(Bosh::Exec).to receive(:sh).and_return(result)

        update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(@stemcell_file.path)

        expect {
          update_stemcell_job.perform
        }.to raise_exception(Bosh::Director::StemcellInvalidArchive)
      end

      context 'when having multiple cpis' do
        let(:cloud_factory) { instance_double(BD::CloudFactory) }
        before {
          allow(BD::CloudFactory).to receive(:new).and_return(cloud_factory)
        }

        it 'creates multiple stemcell records with different cpi attributes' do
          cloud1 = cloud
          cloud2 = cloud
          cloud3 = cloud

          expect(cloud1).to receive(:create_stemcell).with(anything, {"ram" => "2gb"}).and_return('stemcell-cid1')
          expect(cloud3).to receive(:create_stemcell).with(anything, {"ram" => "2gb"}).and_return('stemcell-cid3')

          expect(cloud1).to receive(:info).and_return({"stemcell_formats" => ["dummy"]})
          expect(cloud2).to receive(:info).and_return({"stemcell_formats" => ["dummy1"]})
          expect(cloud3).to receive(:info).and_return({"stemcell_formats" => ["dummy"]})

          expect(cloud_factory).to receive(:all_configured_clouds).twice.and_return([
                                                                                        {name: 'cloud1', cpi: cloud1},
                                                                                        {name: 'cloud2', cpi: cloud2},
                                                                                        {name: 'cloud3', cpi: cloud3},
                                                                                    ])

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
          expect(event_log_stage).to receive(:advance_and_track).exactly(expected_steps - step_messages.count-3).times

          update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(@stemcell_file.path)
          update_stemcell_job.perform

          stemcells = Bosh::Director::Models::Stemcell.where(:name => "jeos", :version => "5").all

          expect(stemcells.count).to eq(2)
          expect(stemcells[0]).not_to be_nil
          expect(stemcells[0].sha1).to eq("shawone")
          expect(stemcells[0].operating_system).to eq("jeos-5")
          expect(stemcells[0].cpi).to eq("cloud1")
          expect(stemcells[0].cid).to eq("stemcell-cid1")

          expect(stemcells[1]).not_to be_nil
          expect(stemcells[1].sha1).to eq("shawone")
          expect(stemcells[1].operating_system).to eq("jeos-5")
          expect(stemcells[1].cpi).to eq("cloud3")
          expect(stemcells[1].cid).to eq("stemcell-cid3")
        end

        it 'still works with the default cpi' do
          expect(cloud).to receive(:info).and_return({"stemcell_formats" => ["dummy"]})
          expect(cloud).to receive(:create_stemcell).with(anything, {"ram" => "2gb"}).and_return('stemcell-cid')

          expect(cloud_factory).to receive(:all_configured_clouds).twice.and_return([{name: '', cpi: cloud}])

          expected_steps = 5
          expect(event_log).to receive(:begin_stage).with('Update stemcell', expected_steps)
          expect(event_log_stage).to receive(:advance_and_track).with('Checking if this stemcell already exists')
          expect(event_log_stage).to receive(:advance_and_track).with('Uploading stemcell jeos/5 to the cloud')
          expect(event_log_stage).to receive(:advance_and_track).with('Save stemcell jeos/5 (stemcell-cid)')
          # seems that rspec already subtracts the expected messages above, so we have to subtract them from the expected overall count
          expect(event_log_stage).to receive(:advance_and_track).exactly(expected_steps - 3).times

          update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(@stemcell_file.path)
          update_stemcell_job.perform

          stemcells = Bosh::Director::Models::Stemcell.where(:name => "jeos", :version => "5").all

          expect(stemcells.count).to eq(1)
          expect(stemcells[0]).not_to be_nil
          expect(stemcells[0].sha1).to eq("shawone")
          expect(stemcells[0].operating_system).to eq("jeos-5")
          expect(stemcells[0].cpi).to eq('')
        end
      end
    end

    context 'when information about stemcell formats is not enough' do
      context 'when stemcell does not have stemcell formats' do
        it 'should not fail' do
          manifest = {
            "name" => "jeos",
            "version" => 5,
            "cloud_properties" => {"ram" => "2gb"},
            "sha1" => "shawone"
          }
          stemcell_contents = create_stemcell(manifest, "image contents")
          @stemcell_file = Tempfile.new("stemcell_contents")

          File.open(@stemcell_file.path, "w") { |f| f.write(stemcell_contents) }
          expect(cloud).to receive(:info).and_return({"stemcell_formats" => ["dummy"]})
          expect(cloud).to receive(:create_stemcell).with(anything, {"ram" => "2gb"}) do |image, _|
            contents = File.open(image) { |f| f.read }
            expect(contents).to eql("image contents")
            "stemcell-cid"
          end

          update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(@stemcell_file.path)

          expect { update_stemcell_job.perform }.not_to raise_error
        end
      end

      context 'when cpi does not have stemcell formats' do
        it 'should not fail' do
          manifest = {
            "name" => "jeos",
            "version" => 5,
            "cloud_properties" => {"ram" => "2gb"},
            "sha1" => "shawone"
          }
          stemcell_contents = create_stemcell(manifest, "image contents")
          @stemcell_file = Tempfile.new("stemcell_contents")

          File.open(@stemcell_file.path, "w") { |f| f.write(stemcell_contents) }
          expect(cloud).to receive(:info).and_return({})
          expect(cloud).to receive(:create_stemcell).with(anything, {"ram" => "2gb"}) do |image, _|
            contents = File.open(image) { |f| f.read }
            expect(contents).to eql("image contents")
            "stemcell-cid"
          end

          update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(@stemcell_file.path)

          expect { update_stemcell_job.perform }.not_to raise_error
        end
      end

      context 'when cpi does not support stemcell formats' do
        it 'should not fail' do
          manifest = {
            "name" => "jeos",
            "version" => 5,
            "cloud_properties" => {"ram" => "2gb"},
            "sha1" => "shawone"
          }
          stemcell_contents = create_stemcell(manifest, "image contents")
          @stemcell_file = Tempfile.new("stemcell_contents")

          File.open(@stemcell_file.path, "w") { |f| f.write(stemcell_contents) }
          expect(cloud).to receive(:info).and_raise(Bosh::Clouds::NotImplemented)
          expect(cloud).to receive(:create_stemcell).with(anything, {"ram" => "2gb"}) do |image, _|
            contents = File.open(image) { |f| f.read }
            expect(contents).to eql("image contents")
            "stemcell-cid"
          end

          update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(@stemcell_file.path)

          expect { update_stemcell_job.perform }.not_to raise_error
        end
      end
    end

    context 'when the stemcell metadata lacks a value for operating_system' do
      before do
        manifest = {
            "name" => "jeos",
            "version" => 5,
            "cloud_properties" => {"ram" => "2gb"},
            "sha1" => "shawone"
        }
        stemcell_contents = create_stemcell(manifest, "image contents")
        @stemcell_file = Tempfile.new("stemcell_contents")
        File.open(@stemcell_file.path, "w") { |f| f.write(stemcell_contents) }
      end

      it 'should not fail' do
        expect(cloud).to receive(:info).and_return({"stemcell_formats" => ["dummy"]})
        expect(cloud).to receive(:create_stemcell).with(anything, {"ram" => "2gb"}) do |image, _|
          contents = File.open(image) { |f| f.read }
          expect(contents).to eql("image contents")
          "stemcell-cid"
        end

        update_stemcell_job = Bosh::Director::Jobs::UpdateStemcell.new(@stemcell_file.path)

        expect { update_stemcell_job.perform }.not_to raise_error
      end
    end

    def create_stemcell(manifest, image)
      io = StringIO.new

      Archive::Tar::Minitar::Writer.open(io) do |tar|
        tar.add_file("stemcell.MF", {:mode => "0644", :mtime => 0}) { |os, _| os.write(manifest.to_yaml) }
        tar.add_file("image", {:mode => "0644", :mtime => 0}) { |os, _| os.write(image) }
      end

      io.close
      gzip(io.string)
    end
  end
end
