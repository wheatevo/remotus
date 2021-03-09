# frozen_string_literal: true

require "openssl"

module Remotus
  module Auth
    # Authentication credential
    class Credential
      # @return [String] gets or sets user
      attr_accessor :user

      # @return [String] gets or sets private key path
      attr_accessor :private_key

      #
      # Generates a new credential from a hash
      #
      # @param [Hash] hash hash with :user, :password, :private_key, and :private_key_data keys
      # @option hash [String] :user user name
      # @option hash [String] :password user password
      # @option hash [String] :private_key private key path
      # @option hash [String] :private_key_data private key data as a string
      #
      # @return [Remotus::Auth::Credential] newly initialized credential
      #
      def self.from_hash(hash)
        Credential.new(
          hash[:user],
          hash[:password],
          private_key: hash[:private_key],
          private_key_data: hash[:private_key_data]
        )
      end

      #
      # Creates a new instance of a Remotus::Auth::Credential
      #
      # @param [String] user user name
      # @param [String] password user password
      # @param [Hash] options options hash
      # @option options [String] :private_key private key path
      # @option options [String] :private_key_data private key data as a string
      #
      def initialize(user, password = nil, **options)
        @user = user
        @crypt_info = { password: {}, private_key_data: {} }
        @private_key = options[:private_key]
        self.password = password
        self.private_key_data = options[:private_key_data]
      end

      #
      # Retrieved decrypted password
      #
      # @return [String, nil] decrypted password or nil if unset
      #
      def password
        return unless @password

        decrypt(@password, :password)
      end

      #
      # Sets password
      #
      # @param [String] password new password
      #
      def password=(password)
        @password = password ? encrypt(password.to_s, :password) : nil
      end

      #
      # Retrieves decrypted private key data
      #
      # @return [String, nil] decrypted private key data or nil if unset
      #
      def private_key_data
        return unless @private_key_data

        decrypt(@private_key_data, :private_key_data)
      end

      #
      # Sets private key data
      #
      # @param [String] private_key_data private key data
      #
      def private_key_data=(private_key_data)
        @private_key_data = private_key_data ? encrypt(private_key_data.to_s, :private_key_data) : nil
      end

      #
      # Converts credential to a string
      #
      # @return [String] Credential represented as a string
      #
      def to_s
        "user: #{@user}"
      end

      #
      # Inspects credential
      #
      # @return [String] Credential represented as an inspection string
      #
      def inspect
        "#{self.class.name}: (#{self})"
      end

      private

      #
      # Encrypts string data
      #
      # @param [String] data data to encrypt
      # @param [Symbol] crypt_key key in @crypt_info to store the key and iv for decryption
      #
      # @return [Object] encrypted data
      #
      def encrypt(data, crypt_key)
        cipher = OpenSSL::Cipher.new("aes-256-cbc")
        cipher.encrypt
        @crypt_info[crypt_key][:key] = cipher.random_key
        @crypt_info[crypt_key][:iv] = cipher.random_iv
        cipher.update(data) + cipher.final
      end

      #
      # Decrypts data to a string
      #
      # @param [Object] data encrypted data
      # @param [Symbol] crypt_key key in @crypt_info containing the key and iv for decryption
      #
      # @return [String] decrypted string
      #
      def decrypt(data, crypt_key)
        decipher = OpenSSL::Cipher.new("aes-256-cbc")
        decipher.decrypt
        decipher.key = @crypt_info[crypt_key][:key]
        decipher.iv = @crypt_info[crypt_key][:iv]
        decipher.update(data) + decipher.final
      end
    end
  end
end
