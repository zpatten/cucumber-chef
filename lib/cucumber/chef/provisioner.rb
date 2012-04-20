require "digest"

module Cucumber
  module Chef
    class ProvisionerError < Error ; end

    class Provisioner
      attr_accessor :stdout, :stderr, :stdin

      def initialize
        @cookbook_path = File.join(File.dirname(__FILE__), "../../../cookbooks/cucumber-chef")
        @stdout, @stderr, @stdin = StringIO.new, StringIO.new, StringIO.new
      end

      def bootstrap_node(config, server)
        template_file = File.join(File.dirname(__FILE__), "templates/ubuntu10.04-gems.erb")
        run_bootstrap(config, template_file, server, chef_node_name(config), "role[test_lab]")
        tag_node(config)
      end

      def build_controller(config, server)
        template_file = File.join(File.dirname(__FILE__), "templates/controller.erb")
        run_bootstrap(config, template_file, server, 'cucumber-chef-controller')
      end

      def upload_cookbook(config)
        version_loader = ::Chef::Cookbook::CookbookVersionLoader.new(@cookbook_path)
        version_loader.load_cookbooks
        uploader = ::Chef::CookbookUploader.new(version_loader.cookbook_version, @cookbook_path)
        # attempt to validate the cookbook
        uploader.validate_cookbook
        # attempt to upload the cookbook
        uploader.upload_cookbook
      end

      def upload_role(config)
        role_path = File.join(@cookbook_path, "roles")
        ::Chef::Config[:role_path] = role_path
        role = ::Chef::Role.from_disk("test_lab")
        role.save
        role = ::Chef::Role.from_disk("controller")
        role.save
      end

      def tag_node(config)
        node = ::Chef::Node.load(chef_node_name)
        node.tags << (config.test_mode? ? 'test' : 'user')
        node.save
      end

    private
      def run_bootstrap(config, template_file, server, node_name, run_list=nil)
        puts("Preparing bootstrap for '#{server.public_ip_address}'.")

        bootstrap = ::Chef::Knife::Bootstrap.new
        ui = ::Chef::Knife::UI.new(STDOUT, STDERR, STDIN, bootstrap.config)
        bootstrap.ui = ui
        bootstrap.name_args = [server.public_ip_address]
        bootstrap.config[:run_list] = run_list
        bootstrap.config[:ssh_user] = "ubuntu"
        bootstrap.config[:identity_file] = config[:knife][:identity_file]
        bootstrap.config[:chef_node_name] = node_name
        bootstrap.config[:use_sudo] = true
        bootstrap.config[:template_file] = template_file
        bootstrap.config[:validation_client_name] = config["validation_client_name"]
        bootstrap.config[:validation_key] = config["validation_key"]
        bootstrap.config[:chef_server_url] = config["chef_server_url"]
        bootstrap.config[:rubygems] = config[:knife][:rubygems]

        # FIXME: this breaks with unquoted STDOUT for log_location in knife.rb
        #bootstrap.config[:log_level] = config["log_level"]
        #bootstrap.config[:log_location] = (config["log_location"].is_a?(File) ? config["log_location"].path : config["log_location"])

        puts("Running bootstrap for '#{server.public_ip_address}'.")
        bootstrap.run

        puts("Finished bootstrapping '#{server.public_ip_address}'.")
        bootstrap
      end

      def chef_node_name(config=nil)
        @node_name ||= begin
          if config.test_mode?
            "cucumber-chef-#{Digest::SHA1.hexdigest(Time.now.to_s)[0..7]}"
          else
            "cucumber-chef-test-lab"
          end
        end
      end

    end
  end
end
