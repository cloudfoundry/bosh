require 'spec_helper'

describe Bosh::Cli::DirectorTask do
  before do
    expect(URI).to receive(:parse).with('http://target.example.com').and_call_original
    credentials = Bosh::Cli::Client::BasicCredentials.new('user', 'pass')
    @director = Bosh::Cli::Client::Director.new('http://target.example.com', credentials)
  end

  it 'tracks partial output responses from director' do
    @task = Bosh::Cli::DirectorTask.new(@director, 10)

    allow(@director).to receive(:get).
      with('/tasks/10/output', nil, nil, 'Range' => 'bytes=0-').
      and_return([206, "test\nout", { :content_range => 'bytes 0-7/100'}])

    allow(@director).to receive(:get).
      with('/tasks/10/output', nil, nil, 'Range' => 'bytes=8-').
      and_return([206, 'put', { :content_range => 'bytes 8-10/100'}])

    allow(@director).to receive(:get).
      with('/tasks/10/output', nil, nil, 'Range' => 'bytes=11-').
      and_return([206, " success\n", { :content_range => 'bytes 11-19/100'}])

    allow(@director).to receive(:get).
      with('/tasks/10/output', nil, nil, 'Range' => 'bytes=20-').
      and_return([416, 'Byte range unsatisfiable', { :content_range => 'bytes */100'}])

    allow(@director).to receive(:get).
      with('/tasks/10/output', nil, nil, 'Range' => 'bytes=20-').
      and_return([206, 'done', {}])

    expect(@task.output).to eq("test\n")
    expect(@task.output).to eq(nil)     # No newline yet
    expect(@task.output).to eq("output success\n") # Got a newline
    expect(@task.output).to eq("done\n") # Flushed
  end

  it 'supports explicit output flush' do
    @task = Bosh::Cli::DirectorTask.new(@director, 10)

    allow(@director).to receive(:get).
      with('/tasks/10/output', nil, nil, 'Range' => 'bytes=0-').
      and_return([206, "test\nout", { :content_range => 'bytes 0-7/100'}])

    expect(@task.output).to eq("test\n")
    expect(@task.flush_output).to eq("out\n")
    # Nothing in buffer at this point
    expect(@task.flush_output).to eq(nil)
  end
end
