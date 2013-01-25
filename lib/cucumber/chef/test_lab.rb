################################################################################
#
#      Author: Stephen Nelson-Smith <stephen@atalanta-systems.com>
#      Author: Zachary Patten <zachary@jovelabs.com>
#   Copyright: Copyright (c) 2011-2013 Atalanta Systems Ltd
#     License: Apache License, Version 2.0
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
################################################################################

module Cucumber
  module Chef

    class TestLabError < Error; end

    class TestLab
      attr_accessor :provider, :stdout, :stderr, :stdin, :logger

################################################################################

      def initialize(stdout=STDOUT, stderr=STDERR, stdin=STDIN, logger=$logger)
        @stdout, @stderr, @stdin, @logger = stdout, stderr, stdin, logger
        @stdout.sync = true if @stdout.respond_to?(:sync=)

        @provider = Cucumber::Chef::Provider.new(@stdout, @stderr, @stdin, @logger)
      end

################################################################################

      def bootstrap_ssh
        dead? and raise TestLabError, "The test lab must be running in order to start a bootstrap SSH session!"

        if (!defined?(@ssh) || @ssh.nil?)
          @ssh ||= ZTK::SSH.new(:stdout => @stdout, :stderr => @stderr, :stdin => @stdin, :timeout => Cucumber::Chef::Config.command_timeout)

          @ssh.config.host_name = self.ip
          @ssh.config.port = self.port
          @ssh.config.user = Cucumber::Chef.bootstrap_user
          @ssh.config.keys = Cucumber::Chef.bootstrap_identity
        end
        @ssh
      end

################################################################################

      def ssh
        dead? and raise TestLabError, "The test lab must be running in order to start an SSH session!"

        if (!defined?(@ssh) || @ssh.nil?)
          @ssh ||= ZTK::SSH.new(:stdout => @stdout, :stderr => @stderr, :stdin => @stdin, :timeout => Cucumber::Chef::Config.command_timeout)

          @ssh.config.host_name = self.ip
          @ssh.config.port = self.port
          @ssh.config.user = Cucumber::Chef.lab_user
          @ssh.config.keys = Cucumber::Chef.lab_identity
        end
        @ssh
      end

################################################################################

      def proxy_ssh(container)
        dead? and raise TestLabError, "The test lab must be running in order to start a proxy SSH session!"

        container = container.to_sym
        @proxy_ssh ||= Hash.new
        if (!defined?(@proxy_ssh[container]) || @proxy_ssh[container].nil?)
          @proxy_ssh[container] ||= ZTK::SSH.new(:stdout => @stdout, :stderr => @stderr, :stdin => @stdin, :timeout => Cucumber::Chef::Config.command_timeout)

          @proxy_ssh[container].config.proxy_host_name = self.ip
          @proxy_ssh[container].config.proxy_port = self.port
          @proxy_ssh[container].config.proxy_user = Cucumber::Chef.lab_user
          @proxy_ssh[container].config.proxy_keys = Cucumber::Chef.lab_identity

          @proxy_ssh[container].config.host_name = container
          @proxy_ssh[container].config.user = Cucumber::Chef.lxc_user
          @proxy_ssh[container].config.keys = Cucumber::Chef.lxc_identity
        end
        @proxy_ssh[container]
      end

################################################################################

      def drb
        dead? and raise TestLabError, "The test lab must be running in order to start a Drb session!"

        # @drb and DRb.stop_service
        @drb ||= DRbObject.new_with_uri("druby://#{self.ip}:8787")
        @drb and DRb.start_service
        @drb
      end

################################################################################

      def cc_server
        @cc_server ||= Cucumber::Chef::Server.new(self, @stdout, @stderr, @stdin, @logger)
        @cc_server
      end

################################################################################

      def method_missing(method_name, *method_args)
        if Cucumber::Chef::Provider::PROXY_METHODS.include?(method_name.to_s)
          result = @provider.send(method_name.to_sym, *method_args)
          splat = [method_name, *method_args].flatten.compact
          Cucumber::Chef.logger.debug { "test_lab: #{splat.inspect} -> #{result.inspect}" }
          result
        else
          super(method_name, *method_args)
        end
      end

################################################################################

    end

  end
end

################################################################################
