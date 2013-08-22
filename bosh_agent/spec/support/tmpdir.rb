require 'tmpdir'

tmpdir = Dir.mktmpdir
ENV['TMPDIR'] = tmpdir
FileUtils.mkdir_p(tmpdir)
at_exit do
  begin
    if $!
      status = $!.is_a?(::SystemExit) ? $!.status : 1
    else
      status = 0
    end
    FileUtils.rm_rf(tmpdir)
  ensure
    exit status
  end
end
