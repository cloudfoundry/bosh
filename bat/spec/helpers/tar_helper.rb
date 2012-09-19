# Copyright (c) 2012 VMware, Inc.

require "zlib"
require "archive/tar/minitar"

module TarHelper
  include Archive::Tar

  def tarfile
    Dir.glob("*.tgz").first
  end

  def tar_contents(tgz)
    list = []
    tar = Zlib::GzipReader.open(tgz)
    Minitar.open(tar).each do |entry|
      list << entry.name if entry.file?
    end
    list
  end

end