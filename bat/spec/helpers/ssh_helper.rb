# Copyright (c) 2012 VMware, Inc.

require "net/ssh"

module SshHelper
  def ssh(host, user, password, command)
    output = nil
    puts "--> ssh: vcap@#{host} '#{command}'" if debug?
    Net::SSH.start(host, user, :password => password, :user_known_hosts_file => %w[/dev/null]) do |ssh|
      output = ssh.exec!(command)
    end
    puts "--> ssh output: '#{output}'" if debug?
    output
  end
end
