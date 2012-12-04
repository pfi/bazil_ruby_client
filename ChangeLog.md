## Version 0.4.0 (2012-12-04) ##

Features:

- SSL option keys change from String to Symbol
 - __WARNING__ This change break compatibility with version 0.3.0
 - Change `Bazil::Client.new(host, port, {"ca_file" => '/path/to/ca_file'})` to `Bazil::Client.new(host, port, {ca_file: '/path/to/ca_file'})`
- ChangeLog: Add ChangeLog


## Version 0.3.0 (2012-07-12) ##

Features:

- Support SSL(https) Option
 - __WARNING__ This change break compatibility with previous version
 - Bazil::Client try to use SSL(https) as default
 - Change `Bazil::Client.new(host, port)` to `Bazil::Client.new(host, port, {'disable_ssl' => true})` to disable SSL
- Add `short_description` to Model configuration
- Support Trace API

Fixes:

- Fix test to support non-string annotation


## Version 0.2.0 (2012-07-10) ##

Features:

- Change `label` property name of training data to `annotation`

Fixes:

- Fixed Error to show error codes in error messages
