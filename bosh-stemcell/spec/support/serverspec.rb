require 'monkeypatch/serverspec/backend/exec'

include Serverspec::Helper::Exec
include Serverspec::Helper::DetectOS

Serverspec::Backend::Exec.instance.chroot_dir = ENV['SERVERSPEC_CHROOT']
