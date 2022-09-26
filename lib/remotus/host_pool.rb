# frozen_string_literal: true

require "remotus"
require "remotus/auth"
require "remotus/ssh_connection"
require "remotus/winrm_connection"
require "remotus/core_ext/string"
require "connection_pool"

module Remotus
  # Class representing a remote connection pool (SSH or WinRM) for a single host
  class HostPool
    # @return [Time] when the host pool will expire
    attr_reader :expiration_time

    # @return [Integer] size of the host connection pool
    attr_reader :size

    # @return [Integer] Number of seconds to wait for a connection from the pool
    attr_reader :timeout

    # @return [Symbol] host pool protocol (:ssh or :winrm)
    attr_reader :proto

    # @return [String] host pool remote host
    attr_reader :host

    # Number of seconds to wait for a connection from the pool by default
    DEFAULT_EXPIRATION_SECONDS = 600

    # Default size of the connection pool
    DEFAULT_POOL_SIZE = 2

    #
    # Creates a host pool for a specific host
    #
    # @param [String] host hostname
    # @param [Integer] size number of connections in the pool (optional)
    # @param [Integer] timeout amount of time to wait for a connection from the pool (optional)
    # @param [Integer] port port to use for the connection
    # @param [Symbol] proto protocol to use for the connection (:winrm, :ssh), must be specified if port is specified
    # @param [Hash] metadata metadata for this connection. Useful for providing additional information to various authentication stores
    #                        should be specified using snake_case symbol keys. If keys are not snake_case, they will be converted.
    #
    #                        To configure a connection gateway, the following metadata entries can be provided to the host pool:
    #                          :gateway_host
    #                          :gateway_port
    #                          :gateway_metadata
    #
    #                        These function similarly to the host, port, and host_pool metadata fields.
    #
    def initialize(host, size: DEFAULT_POOL_SIZE, timeout: DEFAULT_EXPIRATION_SECONDS, port: nil, proto: nil, **metadata)
      Remotus.logger.debug { "Creating host pool for #{host}" }

      # Update metadata information and generate the necessary accessor methods
      @metadata = metadata
      update_metadata_methods

      @host = host
      @proto = proto || Remotus.host_type(host)

      raise Remotus::HostTypeDeterminationError, "Could not determine whether to use SSH or WinRM for #{host}" unless @proto

      connection_class = Object.const_get("Remotus::#{@proto.capitalize}Connection")
      port ||= connection_class::REMOTE_PORT

      @pool = ConnectionPool.new(size: size, timeout: timeout) { connection_class.new(host, port, host_pool: self) }
      @size = size.to_i
      @timeout = timeout.to_i
      @expiration_time = Time.now + timeout
    end

    #
    # Whether the pool is currently expired
    #
    # @return [Boolean] whether pool is expired
    #
    def expired?
      Time.now > @expiration_time
    end

    #
    # Force immediate expiration of the pool
    #
    def expire
      Remotus.logger.debug { "Expiring #{@proto} host pool #{object_id} (#{@host})" }
      @expiration_time = Time.now
    end

    #
    # Closes all open connections in the pool.
    # @see Remotus::SshConnection#close
    # @see Remotus::WinrmConnection#close
    #
    def close
      @pool.reload(&:close)
    end

    #
    # Provides an SSH or WinRM connection to a given block of code
    #
    # @example Run a command over SSH or WinRM using a pooled connection
    #   pool.with { |c| c.run("ls") }
    #
    # @param [Hash] options options hash
    # @option options [Integer] :timeout amount of time to wait for a connection if none is available
    #
    # @return [Object] return value of the provided block
    #
    def with(**options, &block)
      # Update expiration time since the pool has been used
      @expiration_time = Time.now + (@timeout + options[:timeout].to_i)
      Remotus.logger.debug { "Updating #{@proto} host pool #{object_id} (#{@host}) expiration time to #{@expiration_time}" }

      # Run the provided block against the connection
      Remotus.logger.debug { "Running block in #{@proto} host pool #{object_id} (#{@host})" }
      @pool.with(options, &block)
    end

    #
    # Gets remote host connection port
    # @see Remotus::SshConnection#port
    # @see Remotus::WinrmConnection#port
    #
    def port
      Remotus.logger.debug { "Getting port from #{@proto} host pool #{object_id} (#{@host})" }
      with(&:port)
    end

    #
    # Checks if connection port is open on the remote host
    # @see Remotus::SshConnection#port_open?
    # @see Remotus::WinrmConnection#port_open?
    #
    def port_open?
      Remotus.logger.debug { "Checking if port is open from #{@proto} host pool #{object_id} (#{@host})" }
      with(&:port_open?)
    end

    #
    # Runs command on the remote host
    # @see Remotus::SshConnection#run
    # @see Remotus::WinrmConnection#run
    #
    def run(command, *args, **options)
      with { |c| c.run(command, *args, **options) }
    end

    #
    # Runs script on the remote host
    # @see Remotus::SshConnection#run_script
    # @see Remotus::WinrmConnection#run_script
    #
    def run_script(local_path, remote_path, *args, **options)
      with { |c| c.run_script(local_path, remote_path, *args, **options) }
    end

    #
    # Uploads file to the remote host
    # @see Remotus::SshConnection#upload
    # @see Remotus::WinrmConnection#upload
    #
    def upload(local_path, remote_path, **options)
      with { |c| c.upload(local_path, remote_path, **options) }
    end

    #
    # Downloads file from the remote host
    # @see Remotus::SshConnection#download
    # @see Remotus::WinrmConnection#download
    #
    def download(remote_path, local_path = nil, **options)
      with { |c| c.download(remote_path, local_path, **options) }
    end

    #
    # Checks if file exists on the remote host
    # @see Remotus::SshConnection#file_exist?
    # @see Remotus::WinrmConnection#file_exist?
    #
    def file_exist?(remote_path, **options)
      with { |c| c.file_exist?(remote_path, **options) }
    end

    #
    # Gets the current host credential (if any)
    # @see Remotus::Auth#credential
    #
    def credential(**options)
      with { |c| Remotus::Auth.credential(c, **options) }
    end

    #
    # Sets the current host credential
    #
    # @param [Remotus::Auth::Credential, Hash] credential new credential
    #
    def credential=(credential)
      # If the credential is a hash, transform it prior to setting it
      credential = Remotus::Auth::Credential.from_hash(credential) unless credential.is_a?(Remotus::Auth::Credential)
      Remotus::Auth.cache[host] = credential
    end

    #
    # Gets HostPool metadata at key
    #
    # @param [Object] key metadata key
    #
    # @return [Object] metadata value
    #
    def [](key)
      @metadata[key]
    end

    #
    # Sets HostPool metadata value at key
    #
    # @param [Object] key metadata key
    # @param [Object] value new metadata value
    #
    def []=(key, value)
      @metadata[key] = value
      update_metadata_methods
    end

    private

    #
    # Updates accessor methods for any defined metadata in @metadata
    #
    def update_metadata_methods
      @metadata.each do |k, _v|
        safe_key = k.to_s.to_method_name

        # Do not allow metadata to be set that conflicts with base HostPool instance methods
        if RESERVED_METHOD_NAMES.include?(safe_key)
          raise Remotus::InvalidMetadataKey, "Cannot use reserved method name #{safe_key} for a metadata key"
        end

        define_singleton_method(safe_key) { @metadata[k] } unless respond_to?(safe_key)
        define_singleton_method("#{safe_key}=".to_sym) { |new_value| @metadata[k] = new_value } unless respond_to?("#{safe_key}=".to_sym)
      end
    end

    # Array of all reserved method names, must set after all methods are defined
    RESERVED_METHOD_NAMES = Remotus::HostPool.instance_methods.freeze
  end
end
