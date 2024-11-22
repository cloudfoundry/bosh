require 'spec_helper'
require 'open3'

describe 'bin/bosh-template' do
  subject(:bin_file) do
    File.expand_path('../../bin/bosh-template', File.dirname(__FILE__))
  end

  let(:template) do
    asset_path('nats.conf.erb')
  end

  let(:rendered) do
    asset_path('nats.conf')
  end

  let(:context) do
    asset_content('nats.json')
  end


  it 'correctly renders a realistic nats config template' do
    output = run("#{bin_file} #{template} --context '#{context}'")

    expect(output[:status].success?).to be(true)
    expect(output[:stdout]).to eq(File.read(rendered))
    expect(output[:stderr]).to eq('')
  end

  context 'when a JSON context is not provided' do
    it 'fails with a clear error' do
      output = run("#{bin_file} #{template}")

      expect(output[:status].success?).to be(false)
      expect(output[:stdout]).to eq('')
      expect(output[:stderr]).to include('missing argument: --context')
    end
  end

  private

  def run(cmd)
    output = {}
    Open3.popen3(cmd) do |_, stdout, stderr, wait_thr|
      output[:stdout] = stdout.read
      output[:stderr] = stderr.read
      output[:status] = wait_thr.value
    end
    output
  end
end
