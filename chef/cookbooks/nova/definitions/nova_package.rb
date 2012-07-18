# Copyright 2011, Dell
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
define :nova_package do

  package("git")
  nova_path = "/opt/nova"
  nova_name="nova-#{params[:name]}"
  if node[:nova][:use_gitrepo]
    git "#{nova_path}" do
      repository node[:nova][:gitrepo]
      reference "stable/essex"
      action :checkout
    end
    execute "setup_nova" do
      command "cd #{nova_path} && python setup.py develop"
      creates "#{nova_path}/nova.egg-info"
    end
    template "/etc/init/#{nova_name}.conf" do
      source "upstart.conf.erb"
      mode 0644
      variables({
        :service_name => nova_name,
        :nova_path => nova_path
      })
    end
    execute "link_service_#{nova_name}" do
      command "ln -s /lib/init/upstart-job /etc/init.d/#{nova_name}"
      creates "/etc/init.d/#{nova_name}"
    end
  else
    package nova_name do
      options "--force-yes -o Dpkg::Options::=\"--force-confdef\""
      action :upgrade
    end
  end

  service nova_name do
    if (platform?("ubuntu") && node.platform_version.to_f >= 10.04)
      restart_command "status #{nova_name} 2>&1 | grep -q Unknown || restart #{nova_name}"
      stop_command "stop #{nova_name}"
      start_command "start #{nova_name}"
      status_command "status #{nova_name} | cut -d' ' -f2 | cut -d'/' -f1 | grep start"
    end
    supports :status => true, :restart => true
    action [:enable, :start]
    subscribes :restart, resources(:template => "/etc/nova/nova.conf"), :immediately
  end

end
