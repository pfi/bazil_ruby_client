require 'net/http'

require 'rubygems'
require 'json'

require 'test_helper'
require 'bazil'

setup_environment = lambda {
  set :host, 'localhost'
  set :port, BAZIL_PORT
  set :client, Bazil::Client.new(host, port)

  set :version, "/v1"
  set :app_name, APP_NAME
}

cleanup_environment = lambda {
  client.delete_all_applications
}

test_app_creation = lambda { 
  set :app, client.create_application(app_name)
}

test_app_deletion = lambda { 
  client.delete_application(app_name)
}

TestCase 'Bazil-server model' do
  beforeCase &setup_environment
  beforeCase do
    set :model_name, 'random'
    set :model_config, {
      'converter_config' => JSON.parse(File.read(CONFIG_PATH)),
      'classifier_config' => {
        'method' => 'nherd',
        'regularization_weight' => 0.2
      }
    }
  end
  before &test_app_creation

  after &test_app_deletion
  afterCase &cleanup_environment

  test 'get_empty_models' do
    result = app.model_names
    expect_true(result.empty?)
  end

  test 'create_random_model' do
    result = app.create_model(model_name, model_config)
    # no exception
    assert_true(result)
  end

  test 'create_random_model_with_invalid_config' do
    assert_error(RuntimeError) { # TODO: check message
      app.create_model(model_name, {}) # no classifier config
    }
  end

  test 'get_models' do
    app.create_model(model_name, model_config)
    assert_equal([model_name], app.model_names)
  end

  test 'update_classifier_config' do
    result = app.create_model(model_name, model_config)
    config = result.config
    config_cc = config['classifier_config']
    assert_equal('nherd', config_cc['method'])
    assert_equal('0.2', config_cc['regularization_weight'].to_s[0..2])
    assert_equal(1, config['revision'])

    classifier_config = {
      'classifier_config' => {
        'method' => 'arow',
        'regularization_weight' => 0.4
      }
    }

    result.update_config(classifier_config)
    config = result.config
    config_cc = config['classifier_config']
    assert_equal('arow', config_cc['method'])
    assert_equal('0.4', config_cc['regularization_weight'].to_s[0..2])
    assert_equal(2, config['revision'])
  end

  test 'update_with_invalid_config', :params => ['', '{', '1234', '"D"'] do
    app.create_model(model_name, model_config)
    Net::HTTP.start(host, port) { |http|
      result = JSON.parse(http.post("#{version}/apps/#{app_name}/models/#{model_name}", param, {'Content-Type' => 'application/json; charset=UTF-8', 'Content-Length' => param.length.to_s}).body)
      expect_true(result.has_key?('errors'))
    }
  end

  # TODO: add update_converter_config

  test 'delete_random_model' do
    app.create_model(model_name, model_config)
    app.delete_model(model_name)
    expect_true(app.model_names.empty?)
  end

  test 'delete_unknown_model' do
    assert_error(RuntimeError) {
      app.delete_model('unknown')
    }
  end
end
