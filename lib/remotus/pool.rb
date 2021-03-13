# frozen_string_literal: true

require "remotus"
require "remotus/host_pool"

module Remotus
  # Class representing a connection pool containing many host-specific pools
  class Pool
    @pool = nil
    @lock = Mutex.new

    class << self
      #
      # Attempts to get the host pool for a given host
      #
      # @param [String] host hostname
      # @param [Hash] options options hash
      # @option options [Integer] :size number of connections in the pool
      # @option options [Integer] :timeout amount of time to wait for a connection from the pool
      # @option options [Integer] :port port to use for the connection
      # @option options [Symbol]  :proto protocol to use for the connection (:winrm, :ssh), must be specified if port is specified
      #
      # @return [Remotus::HostPool] Host pool for the given host
      #
      def connect(host, **options)
        host_pool(host, **options)
      end

      #
      # Number of host pools in the pool
      #
      # @return [Integer] number of host pools
      #
      def count
        pool.keys.count
      end

      #
      # Reaps (removes) expired host pools from the pool in a thread-safe manner
      #
      # @return [Integer] number of host pools reaped
      #
      def reap
        @lock.synchronize do
          return reap_host_pools
        end
      end

      #
      # Removes all host pools from the pool in a thread-safe manner
      #
      # @return [Integer] number of host pools removed
      #
      def clear
        @lock.synchronize do
          Remotus.logger.debug { "Removing all host pools" }
          return 0 unless @pool

          num_pools = count
          @pool.reject! { |_hostname, _host_pool| true }
          return num_pools
        end
      end

      private

      #
      # Reaps (removes) expired host pools from the pool
      # This is not thread-safe and should be executed from within a mutex block
      #
      # @return [Integer] number of host pools reaped
      #
      def reap_host_pools
        Remotus.logger.debug { "Reaping expired host pools" }

        # If the pool is not yet initialized, no processes can be reaped
        return 0 unless @pool

        # reap all expired host pools
        pre_reap_num_pools = count
        @pool.reject! { |_hostname, host_pool| host_pool.expired? }
        post_reap_num_pools = count

        # Calculate the number of pools reaped
        pools_reaped = pre_reap_num_pools - post_reap_num_pools

        Remotus.logger.debug { "Reaped #{pools_reaped} expired host pools" }

        pools_reaped
      end

      #
      # Retrieves the current pool hash or creates it if it does not exist
      #
      # @return [Hash] Pool hash of FQDN host keys and Remotus::HostPool values
      #
      def pool
        @pool ||= make_pool
      end

      #
      # Creates a new pool
      #
      # @return [Hash] new pool
      #
      def make_pool
        @lock.synchronize do
          Remotus.logger.debug { "Creating Pool container for host pools" }
          return @pool if @pool

          {}
        end
      end

      #
      # Retrieves the host pool for a given host
      # If the host pool does not exist, a new host pool is created
      #
      # @param [String] host hostname
      #
      # @return [Remotus::HostPool] host pool for the given host
      #
      def host_pool(host, **options)
        Remotus.logger.debug { "Getting host pool for #{host}" }

        # If any options are altered, remake the hostpool
        if host_pool_changed?(host, **options)
          expire_host_pool(host)
          return pool[host] = make_host_pool(host, **options)
        end

        pool[host] ||= make_host_pool(host, **options)
      end

      #
      # Whether a given host's pool exists and will be changed by new parameters
      #
      # @param [String] host hostname
      # @param [Hash] options options
      #
      # @return [Boolean] true if the host pool exists and will be changed, false otherwise
      #
      def host_pool_changed?(host, **options)
        return false unless pool[host]

        options.each do |k, v|
          Remotus.logger.debug { "Checking if option #{k} => #{v} has changed" }

          next unless pool[host].respond_to?(k.to_sym)

          host_value = pool[host].send(k.to_sym)

          if v != host_value
            Remotus.logger.debug { "Host value #{host_value} differs from #{v}, host pool has changed" }
            return true
          end
        end

        false
      end

      #
      # Creates a new host pool and stores it in the pool
      #
      # @param [String] host hostname
      #
      # @return [Remotus::HostPool] host pool for the given host
      #
      def make_host_pool(host, **options)
        @lock.synchronize do
          reap_host_pools
          return @pool[host] if @pool[host]

          Remotus::HostPool.new(host, **options)
        end
      end

      #
      # Expires a host pool in the current pool
      #
      # @param [String] host hostname
      #
      def expire_host_pool(host)
        @lock.synchronize do
          return unless @pool[host]

          @pool[host].expire
        end
      end
    end
  end
end
