# frozen_string_literal: true

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
      return cache[connection.host] if cache.key?(connection.host)

      stores.each do |store|
        host_cred = store.credential(connection, **options)
        if host_cred
          cache[connection.host] = host_cred
          return host_cred
        end
      end
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
  end
end
