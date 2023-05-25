## [1.1.0] - 2023-05-25
* Improve exponential backoff during SSH retries.
* Force connection close on IOError (closed stream).

## [1.0.0] - 2023-04-25
* Update SSH dependencies to handle `pkeys are immutable on OpenSSL 3.0` errors on newer Ruby versions
* Remove Ruby 2.5 support

## [0.6.0] - 2022-09-26
* Add `#close` method to all connection types
* Fix SSH gateway connection caching
* Ensure SSH gateway connections are closed gracefully before reinitializing a connection

## [0.5.0] - 2022-09-21
* Ensure port argument is respected in `Remotus::SshConnection`
* Add SSH gateway support

## [0.4.0] - 2022-06-02
* Added winrm-elevated gem to solve wirnrm AuthenticationError

## [0.3.0] - 2022-02-18
* Add retries to SSH SCP transactions

## [0.2.3] - 2021-05-01
* Resolve rexml vulnerability CVE-2021-28965

## [0.2.2] - 2021-03-23
* Ensure both user and password are populated before using a cached credential

## [0.2.1] - 2021-03-15
* Fix connection pooling metadata sharing
* Fix caching of pooled metadata

## [0.2.0] - 2021-03-14
* Add per-connection metadata support

## [0.1.0] - 2021-03-09
* Initial release
