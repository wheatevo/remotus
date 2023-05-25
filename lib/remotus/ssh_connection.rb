# frozen_string_literal: true

require "forwardable"
require "remotus"
require "remotus/result"
require "remotus/auth"
require "net/scp"
require "net/ssh"
require "net/ssh/gateway"

module Remotus
  # Class representing an SSH connection to a host
  class SshConnection
    extend Forwardable

    # Standard SSH remote port
    REMOTE_PORT = 22

    # Standard SSH keepalive interval
    KEEPALIVE_INTERVAL = 300

    # Number of default retries
    DEFAULT_RETRIES = 8

    # Base options for new SSH connections
    BASE_CONNECT_OPTIONS = { non_interactive: true, keepalive: true, keepalive_interval: KEEPALIVE_INTERVAL }.freeze

    # @return [Integer] Remote port
    attr_reader :port

    # @return [String] host hostname
    attr_reader :host

    # @return [Remotus::HostPool] host_pool associated host pool
    attr_reader :host_pool

    # Delegate metadata methods to associated host pool
    def_delegators :@host_pool, :[], :[]=

    # Internal gateway connection class to allow for the host and metadata to be pulled for the gateway
    # by authentication credentials
    class GatewayConnection
      extend Forwardable

      # @return [String] host gateway hostname
      attr_reader :host

      # @return [Integer] Remote port
      attr_reader :port

      # @return [Net::SSH::Gateway] connection gateway connection
      attr_accessor :connection

      # Delegate metadata methods to associated hash
      def_delegators :@metadata, :[], :[]=

      #
      # Creates a GatewayConnection
      #
      # @param [String] host hostname
      # @param [Integer] port remote port
      # @param [Hash] metadata associated metadata for this gateway
      #
      def initialize(host, port = REMOTE_PORT, metadata = {})
        @host = host
        @port = port
        @metadata = metadata
      end
    end

    #
    # Creates an SshConnection
    #
    # @param [String] host hostname
    # @param [Integer] port remote port
    # @param [Remotus::HostPool] host_pool associated host pool
    #                                      To configure the gateway, the following metadata
    #                                      entries can be provided to the host pool:
    #                                        :gateway_host
    #                                        :gateway_port
    #                                        :gateway_metadata
    #
    #                                      These function similarly to the host, port, and host_pool metadata fields.
    #
    def initialize(host, port = REMOTE_PORT, host_pool: nil)
      Remotus.logger.debug { "Creating SshConnection #{object_id} for #{host}" }
      @host = host
      @port = port
      @host_pool = host_pool
    end

    #
    # Connection type
    #
    # @return [Symbol] returns :ssh
    #
    def type
      :ssh
    end

    #
    # Retrieves/creates the base SSH connection for the host
    # If the base connection already exists, the existing connection will be retrieved
    #
    # The SSH connection will be the same whether it is retrieved via base_connection or connection.
    #
    # @return [Net::SSH::Connection::Session] base SSH remote connection
    #
    def base_connection
      connection
    end

    #
    # Retrieves/creates the SSH connection for the host
    # If the connection already exists, the existing connection will be retrieved
    #
    # @return [Net::SSH::Connection::Session] remote connection
    #
    def connection
      return @connection unless restart_connection?

      # Close any active connections
      close

      target_cred = Remotus::Auth.credential(self)

      Remotus.logger.debug { "Initializing SSH connection to #{target_cred.user}@#{@host}:#{@port}" }

      target_options = BASE_CONNECT_OPTIONS.dup
      target_options[:password] = target_cred.password if target_cred.password
      target_options[:keys] = [target_cred.private_key] if target_cred.private_key
      target_options[:key_data] = [target_cred.private_key_data] if target_cred.private_key_data
      target_options[:port] = @port || REMOTE_PORT

      if via_gateway?
        @gateway = GatewayConnection.new(@host_pool[:gateway_host], @host_pool[:gateway_port], @host_pool[:gateway_metadata])
        gateway_cred = Remotus::Auth.credential(@gateway)
        gateway_options = BASE_CONNECT_OPTIONS.dup
        gateway_options[:port] = @gateway.port || REMOTE_PORT
        gateway_options[:password] = gateway_cred.password if gateway_cred.password
        gateway_options[:keys] = [gateway_cred.private_key] if gateway_cred.private_key
        gateway_options[:key_data] = [gateway_cred.private_key_data] if gateway_cred.private_key_data

        Remotus.logger.debug { "Initializing SSH gateway connection to #{gateway_cred.user}@#{@gateway.host}:#{gateway_options[:port]}" }

        @gateway.connection = Net::SSH::Gateway.new(@gateway.host, gateway_cred.user, **gateway_options)
        @connection = @gateway.connection.ssh(@host, target_cred.user, **target_options)
      else
        @connection = Net::SSH.start(@host, target_cred.user, **target_options)
      end
    end

    #
    # Closes the current SSH connection if it is active
    #
    def close
      @connection&.close

      @gateway&.connection&.shutdown! if via_gateway?

      @gateway = nil
      @connection = nil
    end

    #
    # Whether the remote host's SSH port is available
    #
    # @return [Boolean] true if available, false otherwise
    #
    def port_open?
      Remotus.port_open?(@host, @port)
    end

    #
    # Runs a command on the host
    #
    # @param [String] command command to run
    # @param [Array] args command arguments
    # @param [Hash] options command options
    # @option options [Boolean] :sudo whether to run the command with sudo (defaults to false)
    # @option options [Boolean] :pty  whether to allocate a terminal (defaults to false)
    # @option options [Integer] :retries number of times to retry a closed connection (defaults to 2)
    # @option options [String] :input stdin input to provide to the command
    # @option options [Array<Integer>] :accepted_exit_codes array of acceptable exit codes (defaults to [0])
    #                                                       only used if :on_error or :on_success are set
    # @option options [Proc] :on_complete callback invoked when the command is finished (whether successful or unsuccessful)
    # @option options [Proc] :on_error callback invoked when the command is unsuccessful
    # @option options [Proc] :on_output callback invoked when any data is received
    # @option options [Proc] :on_stderr callback invoked when stderr data is received
    # @option options [Proc] :on_stdout callback invoked when stdout data is received
    # @option options [Proc] :on_success callback invoked when the command is successful
    #
    # @return [Remotus::Result] result describing the stdout, stderr, and exit status of the command
    #
    def run(command, *args, **options)
      command = "#{command}#{args.empty? ? "" : " "}#{args.join(" ")}"
      input = options[:input] || +""
      stdout = +""
      stderr = +""
      output = +""
      exit_code = nil
      retries ||= options[:retries] || DEFAULT_RETRIES
      accepted_exit_codes = options[:accepted_exit_codes] || [0]

      ssh_command = command

      # Refer to the command by object_id throughout the log to avoid logging sensitive data
      Remotus.logger.debug { "Preparing to run command #{command.object_id} on #{@host}" }

      with_retries(command, retries) do
        # Handle sudo
        if options[:sudo]
          Remotus.logger.debug { "Sudo is enabled for command #{command.object_id}" }
          ssh_command = "sudo -p '' -S sh -c '#{command.gsub("'", "'\"'\"'")}'"
          input = "#{Remotus::Auth.credential(self).password}\n#{input}"

          # If password was nil, raise an exception
          raise Remotus::MissingSudoPassword, "#{host} credential does not have a password specified" if input.start_with?("\n")
        end

        # Allocate a terminal if specified
        pty = options[:pty] || false
        skip_first_output = pty && options[:sudo]

        # Open an SSH channel to the host
        channel_handle = connection.open_channel do |channel|
          # Execute the command
          if pty
            Remotus.logger.debug { "Requesting pty for command #{command.object_id}" }
            channel.request_pty do |ch, success|
              raise Remotus::PtyError, "could not obtain pty" unless success

              ch.exec(ssh_command)
            end
          else
            Remotus.logger.debug { "Executing command #{command.object_id}" }
            channel.exec(ssh_command)
          end

          # Provide input
          unless input.empty?
            Remotus.logger.debug { "Sending input for command #{command.object_id}" }
            channel.send_data input
            channel.eof!
          end

          # Process stdout
          channel.on_data do |ch, data|
            # Skip the first iteration if sudo and pty is enabled to avoid outputting the sudo password
            if skip_first_output
              skip_first_output = false
              next
            end
            stdout << data
            output << data
            options[:on_stdout].call(ch, data) if options[:on_stdout].respond_to?(:call)
            options[:on_output].call(ch, data) if options[:on_output].respond_to?(:call)
          end

          # Process stderr
          channel.on_extended_data do |ch, _, data|
            stderr << data
            output << data
            options[:on_stderr].call(ch, data) if options[:on_stderr].respond_to?(:call)
            options[:on_output].call(ch, data) if options[:on_output].respond_to?(:call)
          end

          # Process exit status/code
          channel.on_request("exit-status") do |_, data|
            exit_code = data.read_long
          end
        end

        # Block until the command has completed execution
        channel_handle.wait

        Remotus.logger.debug { "Generating result for command #{command.object_id}" }
        result = Remotus::Result.new(command, stdout, stderr, output, exit_code)

        # If we are using sudo and experience an authentication failure, raise an exception
        if options[:sudo] && result.error? && !result.stderr.empty? && result.stderr.match?(/^sudo: \d+ incorrect password attempts?$/)
          raise Remotus::AuthenticationError, "Could not authenticate to sudo as #{Remotus::Auth.credential(self).user}"
        end

        # Perform success, error, and completion callbacks
        options[:on_success].call(result) if options[:on_success].respond_to?(:call) && result.success?(accepted_exit_codes)
        options[:on_error].call(result) if options[:on_error].respond_to?(:call) && result.error?(accepted_exit_codes)
        options[:on_complete].call(result) if options[:on_complete].respond_to?(:call)

        result
      end
    end

    #
    # Uploads a script and runs it on the host
    #
    # @param [String] local_path local path of the script (source)
    # @param [String] remote_path remote path for the script (destination)
    # @param [Array] args script arguments
    # @param [Hash] options command options
    # @option options [Boolean] :sudo whether to run the script with sudo (defaults to false)
    # @option options [Boolean] :pty  whether to allocate a terminal (defaults to false)
    # @option options [Integer] :retries number of times to retry a closed connection (defaults to 2)
    # @option options [String] :input stdin input to provide to the command
    # @option options [Array<Integer>] :accepted_exit_codes array of acceptable exit codes (defaults to [0])
    #                                                       only used if :on_error or :on_success are set
    # @option options [Proc] :on_complete callback invoked when the command is finished (whether successful or unsuccessful)
    # @option options [Proc] :on_error callback invoked when the command is unsuccessful
    # @option options [Proc] :on_output callback invoked when any data is received
    # @option options [Proc] :on_stderr callback invoked when stderr data is received
    # @option options [Proc] :on_stdout callback invoked when stdout data is received
    # @option options [Proc] :on_success callback invoked when the command is successful
    #
    # @return [Remotus::Result] result describing the stdout, stderr, and exit status of the command
    #
    def run_script(local_path, remote_path, *args, **options)
      upload(local_path, remote_path, **options)
      Remotus.logger.debug { "Running script #{remote_path} on #{@host}" }
      run("chmod +x #{remote_path}", **options)
      run(remote_path, *args, **options)
    end

    #
    # Uploads a file from the local host to the remote host
    #
    # @param [String] local_path local path to upload the file from (source)
    # @param [String] remote_path remote path to upload the file to (destination)
    # @param [Hash] options upload options
    # @option options [Boolean] :sudo whether to run the upload with sudo (defaults to false)
    # @option options [String] :owner file owner ("oracle")
    # @option options [String] :group file group ("dba")
    # @option options [String] :mode file mode ("0640")
    # @option options [Integer] :retries number of times to retry a closed connection (defaults to 2)
    #
    # @return [String] remote path
    #
    def upload(local_path, remote_path, options = {})
      Remotus.logger.debug { "Uploading file #{local_path} to #{@host}:#{remote_path}" }

      if options[:sudo]
        sudo_upload(local_path, remote_path, options)
      else
        permission_cmd = permission_cmds(remote_path, options[:owner], options[:group], options[:mode])

        with_retries("Upload #{local_path} to #{remote_path}", options[:retries] || DEFAULT_RETRIES) do
          connection.scp.upload!(local_path, remote_path, options)
        end

        run(permission_cmd).error! unless permission_cmd.empty?
      end

      remote_path
    end

    #
    # Downloads a file from the remote host to the local host
    #
    # @param [String] remote_path remote path to download the file from (source)
    # @param [String] local_path local path to download the file to (destination)
    #                            if local_path is nil, the file's content will be returned
    # @param [Hash] options download options
    # @option options [Boolean] :sudo whether to run the download with sudo (defaults to false)
    # @option options [Integer] :retries number of times to retry a closed connection (defaults to 2)
    #
    # @return [String] local path or file content (if local_path is nil)
    #
    def download(remote_path, local_path = nil, options = {})
      # Support short calling syntax (download("remote_path", option1: 123, option2: 234))
      if local_path.is_a?(Hash)
        options = local_path
        local_path = nil
      end

      # Sudo prep
      if options[:sudo]
        # Must first copy the file to an accessible directory for the login user to download it
        user_remote_path = sudo_remote_file_path(remote_path)
        Remotus.logger.debug { "Sudo enabled, copying file from #{@host}:#{remote_path} to #{@host}:#{user_remote_path}" }
        run("/bin/cp -f '#{remote_path}' '#{user_remote_path}' && chown #{Remotus::Auth.credential(self).user} '#{user_remote_path}'",
            sudo: true).error!
        remote_path = user_remote_path
      end

      Remotus.logger.debug { "Downloading file from #{@host}:#{remote_path}" }

      result = nil

      with_retries("Download #{remote_path} to #{local_path}", options[:retries] || DEFAULT_RETRIES) do
        result = connection.scp.download!(remote_path, local_path, options)
      end

      # Return the file content if that is desired
      local_path.nil? ? result : local_path
    ensure
      # Sudo cleanup
      if options[:sudo]
        Remotus.logger.debug { "Sudo enabled, removing temporary file from #{@host}:#{user_remote_path}" }
        run("/bin/rm -f '#{user_remote_path}'", sudo: true).error!
      end
    end

    #
    # Checks if a remote file or directory exists
    #
    # @param [String] remote_path remote path to the file or directory
    # @param [Hash] options command options
    # @option options [Boolean] :sudo whether to run the check with sudo (defaults to false)
    # @option options [Boolean] :pty  whether to allocate a terminal (defaults to false)
    #
    # @return [Boolean] true if the file or directory exists, false otherwise
    #
    def file_exist?(remote_path, **options)
      Remotus.logger.debug { "Checking if file #{remote_path} exists on #{@host}" }
      run("test -f '#{remote_path}' || test -d '#{remote_path}'", **options).success?
    end

    private

    #
    # Wraps one or many SSH commands to provide exception handling and retry support
    # to a given block
    #
    # @param [String] command command to be run or command description
    # @param [Integer] retries number of retries
    #
    def with_retries(command, retries)
      sleep_time = 1

      yield if block_given?
    rescue Remotus::AuthenticationError, Net::SSH::AuthenticationFailed => e
      # Re-raise exception if the retry count is exceeded
      Remotus.logger.debug do
        "Sudo authentication failed for command #{command.object_id}, retrying with #{retries} attempt#{retries.abs == 1 ? "" : "s"} remaining..."
      end
      retries -= 1
      raise Remotus::AuthenticationError, e.to_s if retries.negative?

      # Remove user password to force credential store update on next retry
      Remotus.logger.debug { "Removing current credential for #{@host} to force credential retrieval." }
      Remotus::Auth.cache.delete(@host)

      retry
    rescue IOError => e
      # Re-raise exception if it is not a closed stream error or if the retry count is exceeded
      Remotus.logger.debug do
        "IOError (#{e}) encountered for command #{command.object_id}, retrying with #{retries} attempt#{retries.abs == 1 ? "" : "s"} remaining..."
      end
      retries -= 1
      raise if e.to_s != "closed stream" || retries.negative?

      # Close the existing connection before retrying again
      close

      Remotus.logger.debug { "Sleeping for #{sleep_time} seconds before next retry..." }
      sleep sleep_time
      sleep_time *= 2 # Double delay for each retry
      retry
    end

    #
    # Whether to restart the current SSH connection
    #
    # @return [Boolean] whether to restart the current connection
    #
    def restart_connection?
      return true unless @connection
      return true if @connection.closed?
      return true if @host != @connection.host

      target_cred = Remotus::Auth.credential(self)

      return true if target_cred.user != @connection.options[:user]
      return true if target_cred.password != @connection.options[:password]
      return true if Array(target_cred.private_key) != Array(@connection.options[:keys])
      return true if Array(target_cred.private_key_data) != Array(@connection.options[:key_data])

      # Perform gateway checks
      if via_gateway?
        return true unless @gateway&.connection&.active?

        gateway_session = @gateway.connection.instance_variable_get(:@session)

        return true if gateway_session.closed?
        return true if @host_pool[:gateway_host] != gateway_session.host

        gateway_cred = Remotus::Auth.credential(@gateway)

        return true if gateway_cred.user != gateway_session.options[:user]
        return true if gateway_cred.password != gateway_session.options[:password]
        return true if Array(gateway_cred.private_key) != Array(gateway_session.options[:keys])
        return true if Array(gateway_cred.private_key_data) != Array(gateway_session.options[:key_data])
      end

      false
    end

    #
    # Generates a temporary remote file path for sudo uploads and downloads
    #
    # @param [String] path remote path
    #
    # @return [String] temporary remote file path
    #
    def sudo_remote_file_path(path)
      # Generate a simple path consisting of the filename, current time, our object ID, and a random hex ID
      temp_file = "#{File.basename(path)}_#{Time.now.to_i}_#{object_id}_#{SecureRandom.hex}"
      temp_file = ".#{temp_file}" unless temp_file.start_with?(".")
      Remotus.logger.debug { "Generated temp file path #{temp_file}" }
      temp_file
    end

    #
    # Uploads a file to a remote node using sudo
    #
    # @param [String] local_path local path to upload the file from (source)
    # @param [String] remote_path remote path to upload the file to (destination)
    # @param [Hash] options upload options
    # @option options [String] :owner file owner ("oracle")
    # @option options [String] :group file group ("dba")
    # @option options [String] :mode file mode ("0640")
    # @option options [Integer] :retries number of times to retry a closed connection (defaults to 2)
    #
    def sudo_upload(local_path, remote_path, options = {})
      # Must first upload the file to an accessible directory for the login user
      user_remote_path = sudo_remote_file_path(remote_path)
      Remotus.logger.debug { "Sudo enabled, uploading file to #{user_remote_path}" }
      permission_cmd = permission_cmds(user_remote_path, options[:owner], options[:group], options[:mode])

      with_retries("Upload #{local_path} to #{user_remote_path}", options[:retries] || DEFAULT_RETRIES) do
        connection.scp.upload!(local_path, user_remote_path, options)
      end

      # Set permissions and move the file to the correct destination
      move_cmd = "/bin/mv -f '#{user_remote_path}' '#{remote_path}'"
      move_cmd = "#{permission_cmd} && #{move_cmd}" unless permission_cmd.empty?

      begin
        Remotus.logger.debug { "Sudo enabled, moving file from #{user_remote_path} to #{remote_path}" }
        run(move_cmd, sudo: true).error!
      rescue StandardError
        # If we failed to set permissions, ensure the remote user path is cleaned up
        Remotus.logger.debug { "Sudo enabled, cleaning up #{user_remote_path}" }
        run("/bin/rm -f '#{user_remote_path}'", sudo: true)
        raise
      end
    end

    #
    # Generates commands to run to set remote file permissions
    #
    # @param [String] path remote file path ("/the/remote/path.txt")
    # @param [String] owner owner ("root")
    # @param [String] group group ("root")
    # @param [String] mode mode ("0755")
    #
    # @return [String] generated permission command string
    #
    def permission_cmds(path, owner, group, mode)
      cmds = ""
      cmds = "/bin/chown #{owner}:#{group} '#{path}'" if owner || group
      cmds = "#{cmds} &&" if !cmds.empty? && mode
      cmds = "#{cmds} /bin/chmod #{mode} '#{path}'" if mode
      Remotus.logger.debug { "Generated permission commands #{cmds}" }
      cmds
    end

    #
    # Whether connecting via an SSH gateway
    #
    # @return [Boolean] true if using a gateway, false otherwise
    #
    def via_gateway?
      host_pool && host_pool[:gateway_host]
    end
  end
end
