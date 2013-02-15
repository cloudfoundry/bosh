# Copyright (c) 2009-2012 VMware, Inc.

class Batarang::Sinatra < Sinatra::Base

  get '/' do
    content_type :json
    {:response => "ok"}.to_json
  end

  get '/disks' do
    content_type :json
    disks = {}
    output = %x{df -x tmpfs -x devtmpfs -x debugfs -l}
    output.split("\n").each do |line|
      fields = line.split(/\s+/)
      disks[fields[0]] = {
          :blocks => fields[1],
          :used => fields[2],
          :available => fields[3],
          :precent => fields[4],
          :mountpoint => fields[5],
      } unless fields[0] == "Filesystem"
    end
    disks.to_json
  end

  get '/nats' do
    content_type :json
    {:nats => Batarang::NATS.instance.state}
  end

  post '/exec' do
    content_type :json
    body = request.body.read
    json = JSON.parse(body)
    halt unless json && json["command"]
    result = Bosh::Exec.sh(json["command"])
    {
      :status => result.exit_status,
      :stdout => result.output
    }.to_json
  end
end
