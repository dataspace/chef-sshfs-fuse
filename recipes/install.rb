#
# Cookbook Name:: sshfs-fuse
# Recipe:: install
#

# template '/etc/passwd-sshfs' do
#   variables(
#     :ssh_key => node['sshfs-fuse'][:ssh_key],
#     :ssh_secret => node['sshfs-fuse'][:ssh_secret]
#   )
# end

prereqs = case node.platform_family
when 'debian'
  %w(
    build-essential
    libfuse-dev
    fuse-utils
    sshfs
  )
when 'rhel'
  %w(
    gcc
    libstdc++-devel
    gcc-c++
    curl-devel
    libxml2-devel
    openssl-devel
    mailcap
  )
else
  raise "Unsupported platform family provided: #{node.platform_family}"
end

prereqs.each do |prereq_name|
  package prereq_name
end

# If we're in redhat land and fuse is ancient, update it
if(node.platform_family == 'rhel')
  %w(fuse fuse* fuse-devel).each do |pkg_name|
    package pkg_name do
      action :remove
    end
  end

  fuse_version = File.basename(node['sshfs-fuse'][:fuse_url]).match(/\d\.\d\.\d/).to_s
  #TODO: /bin/true is an ugly hack
  fuse_check = [
    {'PKG_CONFIG_PATH' => '/usr/lib/pkgconfig:/usr/lib64/pkgconfig'},
    '/usr/bin/pkg-config',
    '--modversion',
    'fuse'
  ]

  remote_file "/tmp/#{File.basename(node['sshfs-fuse'][:fuse_url])}" do
    source "#{node['sshfs-fuse'][:fuse_url]}?ts=#{Time.now.to_i}&use_mirror=#{node['sshfs-fuse'][:fuse_mirror]}"
    action :create_if_missing
    not_if do
      IO.popen(fuse_check).readlines.join('').strip == fuse_version
    end
  end

  bash "compile_and_install_fuse" do
    cwd '/tmp'
    code <<-EOH
      tar -xzf fuse-#{fuse_version}.tar.gz
      cd fuse-#{fuse_version}
      ./configure --prefix=/usr
      make
      make install
      export PKG_CONFIG_PATH=/usr/lib/pkgconfig:/usr/lib64/pkgconfig
      ldconfig
      modprobe fuse
    EOH
    not_if do
      IO.popen(fuse_check).readlines.join('').strip == fuse_version
    end
  end

end

bash "load_fuse" do
  code <<-EOH
    modprobe fuse
  EOH
  not_if{ 
    system('lsmod | grep fuse > /dev/null') ||
    system('cat /boot/config-`uname -r` | grep -P "^CONFIG_FUSE_FS=y$" > /dev/null')
  }
end


