# Remotus

Remotus provides a simple ruby interface for pooling remote SSH and WinRM connections and managing remote credentials. Custom authentication stores may be added to allow remote credentials to be automatically retrieved.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'remotus'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install remotus

## Usage

```ruby
# Initialize a new connection pool to remotehost.local and auto-determine whether to use SSH or WinRM
connection = Remotus.connect("remotehost.local")

# Initialize a new connection pool to remotehost.local with a defined protocol and port
connection = Remotus.connect("remotehost.local", proto: :ssh, port: 2222)

# Initialize a new connection pool to remotehost.local with a defined protocol and port and arbitrary metadata
connection = Remotus.connect("remotehost.local", proto: :ssh, port: 2222, company: "Test Corp", location: "Oslo")

# Create a credential for the new connection pool
connection.credential = Remotus::Auth::Credential.new("username", "password")

# Run a command on the remote host
result = connection.run("hostname")

result.command
# => "hostname"

result.stdout
# => "remotehost.local\n"

result.stderr
# => ""

result.output
# => "remotehost.local\n"

result.exit_code
# => 0

# Run a command on the remote host with sudo (Linux only, requires password to be specified)
result = connection.run("ls /root", sudo: true)

# Run a command on the remote host with elevated shell privilege
result = connection.run("ipconfg", shell: :elevated)

# Run a script on the remote host
connection.run_script("/local/script.sh", "/remote/path/script.sh")

# Run a script on the remote host with arguments
connection.run_script("/local/script.sh", "/remote/path/script.sh", "arg1", "arg2")

# Upload a file to the remote host
connection.upload("/local/file.txt", "/remote/path/file.txt")

# Download a file from the remote host
connection.download("/remote/path/file.txt", "/local/file.txt")
```

Full documentation is available in the [Remotus GitHub Pages](https://wheatevo.github.io/remotus/).

### Extending Remotus

Remotus may be extended by adding more authentication stores to gather remote credential data from centralized services.

#### Authentication Stores

More authentication stores may be added by creating a new class that inherits from `Remotus::Auth::Store` and implementing the `credential` method. The `credential` method should receive a `Remotus::SshConnection` or `Remotus::WinrmConnection` and an options hash and return a `Remotus::Auth::Credential` or `nil` if no credential can be found.

Once a new authentication store has been defined, ensure it is used by Remotus by adding it to `Remotus::Auth.stores`.

```ruby
# Define a new authentication store that returns "<hostname>_password" for any connection
#
# This is for demonstration purposes only, please do not use any password with your hostname or "password" in it :)
require "remotus"

class SimpleStore < Remotus::Auth::Store
  def credential(connection, **options)
    Remotus::Auth::Credential.new('user', "#{connection.host}_password")
  end
end

# Add the authentication store to the array of existing authentication stores
Remotus::Auth.stores << SimpleStore.new

# Use the authentication store
connection = Remotus.connect("remotehost.local", proto: :ssh)
Remotus::Auth.credential(connection)
# => "remotehost.local_password"
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/wheatevo/remotus.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
