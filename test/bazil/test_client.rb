require 'rubygems'
require 'json'
require 'bazil'

TestCase 'Bazil::Client::initilize' do
  beforeCase do
    set :client, Bazil::Client.new('example.com', 30000)
    set :http, Net::HTTP.new('exmaple.com', 30000)
    set :exists_abs_path, File::absolute_path(__FILE__)
  end

  test 'get_disable_ssl_option_default' do
    expect_false(client.__send__(:get_disable_ssl_option, {}))
  end
  test 'get_disable_ssl_option_true' do
    expect_true(client.__send__(:get_disable_ssl_option, {"disable_ssl" => true}))
  end
  test 'get_disable_ssl_option_false' do
    expect_false(client.__send__(:get_disable_ssl_option, {"disable_ssl" => false}))
  end

  test 'get_ca_file_option_default' do
    expect_equal(nil, client.__send__(:get_ca_file_option, {}))
  end
  test 'get_ca_file_option_valid' do
    expect_equal(exists_abs_path, client.__send__(:get_ca_file_option, {"ca_file" => exists_abs_path}))
  end
  test 'get_ca_file_option_relative_path' do
    assert_error(RuntimeError) {
      client.__send__(:get_ca_file_option, {"ca_file" => 'relative/path/to/somewhere'})
    }
  end
  test 'get_ca_file_option_not_exists' do
    assert_error(RuntimeError) {
      client.__send__(:get_ca_file_option, {"ca_file" => "/:path:/:to:/:never:/:exist:/:file:"})
    }
  end

  test 'get_ssl_version_option_default' do
    expect_equal("TLSv1", client.__send__(:get_ssl_version_option, {}))
  end
  test 'get_ssl_version_option_tlsv1' do
    expect_equal("TLSv1", client.__send__(:get_ssl_version_option, {"version" => :TLSv1}))
  end
  test 'get_ssl_version_option_sslv3' do
    expect_equal("SSLv3", client.__send__(:get_ssl_version_option, {"version" => :SSLv3}))
  end
  test 'get_ssl_version_option_sslv2' do
    assert_error(RuntimeError) {
      client.__send__(:get_ssl_version_option, {"version" => :SSLv2})
    }
  end

  test 'get_verify_mode_option_default' do
    expect_equal(OpenSSL::SSL::VERIFY_PEER, client.__send__(:get_verify_mode_option, {}))
  end
  test 'get_verify_mode_option_true' do
    expect_equal(OpenSSL::SSL::VERIFY_NONE, client.__send__(:get_verify_mode_option, {"skip_verify" => true}))
  end
  test 'get_verify_mode_option_false' do
    expect_equal(OpenSSL::SSL::VERIFY_PEER, client.__send__(:get_verify_mode_option, {"skip_verify" => false}))
  end

  test 'set_ssl_options_ca_file_with_disable_ssl' do
    assert_error(RuntimeError) {
      client.__send__(:set_ssl_options, http, {"disable_ssl" => true, "ca_file" => exists_abs_path})
    }
  end
  test 'set_ssl_options_ssl_version_with_disable_ssl' do
    assert_error(RuntimeError) {
      client.__send__(:set_ssl_options, http, {"disable_ssl" => true, "version" => :SSLv3})
    }
  end
  test 'set_ssl_options_verify_mode_with_disable_ssl' do
    assert_error(RuntimeError) {
      client.__send__(:set_ssl_options, http, {"disable_ssl" => true, "skip_verify" => true})
    }
  end
end
