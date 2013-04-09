define :execute_in_chroot, :root_dir => "/" do
  execute "#{params[:name]} with root directory #{params[:root_dir]}" do
    action :run
    name = params[:name].gsub(/\s+/, '_')
    command <<-BASH
      echo '#{params[:command]}' > #{params[:root_dir]}/tmp/#{name}.sh
      chroot #{params[:root_dir]} bin/bash /tmp/#{name}.sh
    BASH
    creates(params[:creates]) if params[:creates]
  end
end
