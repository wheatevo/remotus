# frozen_string_literal: true

require "remotus"
require "remotus/auth/credential"
require "remotus/auth/store"
require "remotus/auth/hash_store"

module Remotus
  # Module containing remote authentication classes and modules
  module Auth
    #
    # Gets authentication credentials for the given connection and options
    #
    # @param [Remotus::SshConnection, Remotus::WinrmConnection, #host] connection remote connection
    # @param [Hash] options options hash
    #                       options may be used by different credential stores.
    #
    # @return [Remotus::Auth::Credential] found credential
    #
    def self.credential(connection, **options)
      # Only return cached credentials that have a populated user and password, otherwise attempt retrieval
      return cache[connection.host] if cache.key?(connection.host) && cache[connection.host].user && cache[connection.host].password

      found_credential = credential_from_stores(connection, **options)
      return found_credential if found_credential

      raise Remotus::MissingCredential, "Could not find credential for #{connection.host} in any credential store (#{stores.join(", ")})."
    end

    #
    # Gets the credential cache
    #
    # @return [Hash{String => Remotus::Auth::Credential}] credential cache with hostname keys
    #
    def self.cache
      @cache ||= {}
    end

    #
    # Clears all entries in the credential cache
    #
    def self.clear_cache
      @cache = {}
    end

    #
    # Gets the list of associated credential stores
    #
    # @return [Array<Remotus::Auth::Store>] credential stores
    #
    def self.stores
      @stores ||= []
    end

    #
    # Sets the list of associated credential stores
    #
    # @param [Array<Remotus::Auth::Store>] stores credential stores
    #
    def self.stores=(stores)
      @stores = stores
    end

    class << self
      private

      #
      # Gets authentication credentials for the given connection and options from one of the credential stores
      #
      # @param [Remotus::SshConnection, Remotus::WinrmConnection, #host] connection remote connection
      # @param [Hash] options options hash
      #                       options may be used by different credential stores.
      #
      # @return [Remotus::Auth::Credential, nil] found credential or nil if the credential cannot be found
      #
      def credential_from_stores(connection, **options)
        stores.each do |store|
          Remotus.logger.debug { "Gathering #{connection.host} credentials from #{store} credential store" }
          host_cred = store.credential(connection, **options)
          next unless host_cred

          Remotus.logger.debug { "#{connection.host} credentials found in #{store} credential store" }
          cache[connection.host] = host_cred
          return host_cred
        end
        nil
      end
    end
  end
end
