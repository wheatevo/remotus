# frozen_string_literal: true

require "remotus"
require "remotus/result"
require "remotus/auth"
require "winrm"
require "winrm-fs"

module Remotus
  # Class representing a WinRM connection to a host
  class WinrmConnection
    # Standard WinRM remote port
    REMOTE_PORT = 5985

    # @return [Integer] Remote port
    attr_reader :port

    # @return [String] host hostname
    attr_reader :host

    #
    # Creates a WinrmConnection
    #
    # @param [String] host hostname
    # @param [Integer] port remote port
    #
    def initialize(host, port = REMOTE_PORT)
      @host = host
      @port = port
    end

    #
    # Connection type
    #
    # @return [Symbol] returns :winrm
    #
    def type
      :winrm
    end

    #
    # Retrieves/creates the base WinRM connection for the host
    # If the base connection already exists, the existing connection will be retrieved
    #
    # @return [WinRM::Connection] base WinRM remote connection
    #
    def base_connection(reload: false)
      return @base_connection if !reload && !restart_base_connection?

      Remotus.logger.debug { "Initializing WinRM connection to #{Remotus::Auth.credential(self).user}@#{@host}:#{@port}" }
      @base_connection = WinRM::Connection.new(
        endpoint: "http://#{@host}:#{@port}/wsman",
        transport: :negotiate,
        user: Remotus::Auth.credential(self).user,
        password: Remotus::Auth.credential(self).password
      )
    end

    #
    # Retrieves/creates the WinRM shell connection for the host
    # If the connection already exists, the existing connection will be retrieved
    #
    # @return [WinRM::Shells::Powershell] remote connection
    #
    def connection
      return @connection unless restart_connection?

      @connection = base_connection(reload: true).shell(:powershell)
    end

    #
    # Whether the remote host's WinRM port is available
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
    # @param [Hash] _options unused command options
    #
    # @return [Remotus::Result] result describing the stdout, stderr, and exit status of the command
    #
    def run(command, *args, **_options)
      command = "#{command}#{args.empty? ? "" : " "}#{args.join(" ")}"
      run_result = connection.run(command)
      Remotus::Result.new(command, run_result.stdout, run_result.stderr, run_result.output, run_result.exitcode)
    rescue WinRM::WinRMAuthorizationError => e
      raise Remotus::AuthenticationError, e.to_s
    end

    #
    # Uploads a script and runs it on the host
    #
    # @param [String] local_path local path of the script (source)
    # @param [String] remote_path remote path for the script (destination)
    # @param [Array] args script arguments
    # @param [Hash] options command options
    #
    # @return [Remotus::Result] result describing the stdout, stderr, and exit status of the command
    #
    def run_script(local_path, remote_path, *args, **options)
      upload(local_path, remote_path)
      run(remote_path, *args, **options)
    end

    #
    # Uploads a file from the local host to the remote host
    #
    # @param [String] local_path local path to upload the file from (source)
    # @param [String] remote_path remote path to upload the file to (destination)
    # @param [Hash] _options unused upload options
    #
    # @return [String] remote path
    #
    def upload(local_path, remote_path, _options = {})
      Remotus.logger.debug { "Uploading file #{local_path} to #{@host}:#{remote_path}" }
      WinRM::FS::FileManager.new(base_connection).upload(local_path, remote_path)
      remote_path
    end

    #
    # Downloads a file from the remote host to the local host
    #
    # @param [String] remote_path remote path to download the file from (source)
    # @param [String] local_path local path to download the file to (destination)
    # @param [Hash] _options unused download options
    #
    # @return [String] local path
    #
    def download(remote_path, local_path, _options = {})
      Remotus.logger.debug { "Downloading file #{local_path} from #{@host}:#{remote_path}" }
      WinRM::FS::FileManager.new(base_connection).download(remote_path, local_path)
      local_path
    end

    #
    # Checks if a remote file or directory exists
    #
    # @param [String] remote_path remote path to the file or directory
    # @param [Hash] _options unused command options
    #
    # @return [Boolean] true if the file or directory exists, false otherwise
    #
    def file_exist?(remote_path, **_options)
      Remotus.logger.debug { "Checking if file #{remote_path} exists on #{@host}" }
      WinRM::FS::FileManager.new(base_connection).exists?(remote_path)
    end

    private

    #
    # Whether to restart the current WinRM base connection
    #
    # @return [Boolean] whether to restart the current base connection
    #
    def restart_base_connection?
      return restart_connection? if @connection
      return true unless @base_connection
      return true if @host != @base_connection.instance_values["connection_opts"][:endpoint].scan(%r{//(.*):}).flatten.first
      return true if Remotus::Auth.credential(self).user != @base_connection.instance_values["connection_opts"][:user]
      return true if Remotus::Auth.credential(self).password != @base_connection.instance_values["connection_opts"][:password]

      false
    end

    #
    # Whether to restart the current WinRM connection
    #
    # @return [Boolean] whether to restart the current connection
    #
    def restart_connection?
      return true unless @connection
      return true if @host != @connection.connection_opts[:endpoint].scan(%r{//(.*):}).flatten.first
      return true if Remotus::Auth.credential(self).user != @connection.connection_opts[:user]
      return true if Remotus::Auth.credential(self).password != @connection.connection_opts[:password]

      false
    end
  end
end
