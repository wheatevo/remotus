# frozen_string_literal: true

module Remotus
  module Auth
    # Hash-based authentication store that requires credentials to be added manually
    class HashStore < Store
      #
      # Creates the HashStore
      #
      def initialize
        super
        @store = {}
      end

      #
      # Retrieves a credential from the hash store
      #
      # @param [Remotus::SshConnection, Remotus::WinrmConnection, #host] connection <description>
      # @param [Hash] _options unused options hash
      #
      # @return [Remotus::Auth::Credential, nil] found credential or nil
      #
      def credential(connection, **_options)
        @store[connection.host.downcase]
      end

      #
      # Adds a credential to the store for a given connection
      #
      # @param [Remotus::SshConnection, Remotus::WinrmConnection, #host] connection associated connection
      # @param [Remotus::Auth::Credential] credential new credential
      #
      def add(connection, credential)
        @store[connection.host.downcase] = credential
      end

      #
      # Removes a credential from the store for a given connection
      #
      # @param [Remotus::SshConnection, Remotus::WinrmConnection, #host] connection associated connection
      #
      def remove(connection)
        @store.delete(connection.host.downcase)
      end

      #
      # String representation of the hash store
      #
      # @return [String] string representation of the hash store
      #
      def to_s
        "HashStore"
      end
    end
  end
end
