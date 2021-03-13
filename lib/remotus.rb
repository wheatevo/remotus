# frozen_string_literal: true

require "remotus/core_ext/string"
require "remotus/version"
require "remotus/logger"
require "remotus/pool"
require "remotus/auth"

# Contains classes and methods for creating remote connections and running commands
module Remotus
  #
  # Creates/gets a host pool for the host that can be used to perform remote operations.
  # After creation, the host pool will persist for future connections.
  #
  # @param [String] host hostname
  # @param [Hash] options options hash
  # @option options [Integer] :size number of connections in the pool
  # @option options [Integer] :timeout amount of time to wait for a connection from the pool
  # @option options [Integer] :port port to use for the connection
  # @option options [Symbol]  :proto protocol to use for the connection (:winrm, :ssh), must be specified if port is specified
  #
  # @return [Remotus::HostPool] Newly created or retrieved host pool
  #
  def self.connect(host, **options)
    Remotus::Pool.connect(host, **options)
  end

  #
  # Number of host pools in the connection pool
  #
  # @return [Integer] number of host pools
  #
  def self.count
    Remotus::Pool.count
  end

  #
  # Removes all host pools from the pool in a thread-safe manner
  #
  # @return [Integer] number of host pools removed
  #
  def self.clear
    Remotus::Pool.clear
  end

  #
  # Checks if a remote port is open
  #
  # @param [String] host remote host
  # @param [Integer] port remote port
  # @param [Integer] timeout amount of time to wait in seconds
  #
  # @return [Boolean] true if port is open, false otherwise
  #
  def self.port_open?(host, port, timeout: 1)
    logger.debug { "Checking if #{host}:#{port} is accessible" }
    Socket.tcp(host, port, connect_timeout: timeout) { true }
  rescue StandardError
    logger.debug { "#{host}:#{port} is inaccessible" }
    false
  end

  #
  # Determine remote host type by checking common ports
  #
  # @param [String] host hostname
  # @param [Integer] timeout amount of time to wait in seconds
  #
  # @return [Symbol, nil] :ssh, :winrm, or nil if it cannot be determined
  #
  def self.host_type(host, timeout: 1)
    return :ssh if port_open?(host, SshConnection::REMOTE_PORT, timeout: timeout)

    return :winrm if port_open?(host, WinrmConnection::REMOTE_PORT, timeout: timeout)

    nil
  end

  #
  # Gets the remotus logger
  #
  # @return [Remotus::Logger] current logger
  #
  def self.logger
    @logger ||= Remotus::Logger.new($stdout, level: Logger::INFO)
  end

  #
  # Sets the remotus logger
  #
  # @param [::Logger] logger logger to set
  #
  def self.logger=(logger)
    if logger.nil?
      self.logger.level = Logger::FATAL
      return self.logger
    end
    @logger = logger
  end

  #
  # Gets the remotus log formatter
  #
  # @return [::Logger::Formatter] current log formatter
  #
  def self.log_formatter
    @log_formatter ||= logger.formatter
  end

  #
  # Sets the remotus log formatter
  #
  # @param [::Logger::Formatter] log_formatter new log formatter
  #
  def self.log_formatter=(log_formatter)
    @log_formatter = log_formatter
    logger.formatter = log_formatter
  end

  # Generic base class for Remotus errors
  class Error < StandardError; end

  # Failed to obtain PTY during SSH connection
  class PtyError < Error; end

  # Failed to determine remote node host type
  class HostTypeDeterminationError < Error; end

  # Failed to authenticate to remote host
  class AuthenticationError < Error; end

  # Raised when a RemoteCommand::Result has an error
  class ResultError < Error; end

  # Raised when a derived class is missing an override method
  class MissingOverride < Error; end

  # Failed to find credential in credential store
  class MissingCredential < Error; end

  # Failed to find credential password when executing sudo command
  class MissingSudoPassword < Error; end

  # Raised when an invalid metadata key is provided to a Remotus HostPool
  class InvalidMetadataKey < Error; end
end
