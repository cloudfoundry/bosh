RSpec::Matchers.define :have_same_tarball_contents do |expected_tar_path|
  match do |actual_tar_path|
    expect(tarball_listing(expected_tar_path)).to match tarball_listing(actual_tar_path)
  end

  failure_message do |actual_tar_path|
    <<-EOF
Expected tarballs to have same contents.
Expected:
#{tarball_listing(expected_tar_path)}

Actual:
#{tarball_listing(actual_tar_path)}
    EOF
  end

  # lists the contents of the given tarball into a multiline string, sorted by pathname
  # strips leading './' in each entry if present
  # omits empty entries (this is typical if the archive contains an initial './' entry)
  def tarball_listing(tarball_path)
    `tar ztf '#{tarball_path}'`.gsub(/^\.\//, '').split("\n").sort.flat_map{ |line|
      ([] if line.empty?) || [ line ]
    }.join("\n")
  end
end
