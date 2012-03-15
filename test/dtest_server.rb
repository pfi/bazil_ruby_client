require 'rubygems'
require 'json'

require 'test_helper'
require 'bazil'

# TODO: add general tests for Model(calling config/status/etc)

TestCase 'Bazil-server app' do
  include_context 'bazil_case_utils'

  before { setup_environment }
  after { cleanup_environment }

  test 'get_status' do
    result = client.status
    expect_true(result.has_key?('running_time'))
    expect_true(result.has_key?('version'))
    expect_true(result.has_key?('epoch_time'))
    expect_true(result.has_key?('num_applications'))
    # TODO: need some test to check if num_applications is working
  end

  test 'get_config' do
    result = client.config
    expect_true(result.has_key?('port'))
    expect_true(result.has_key?('num_threads'))
    expect_true(result.has_key?('export_dir'))
    expect_true(result.has_key?('protocol'))

    expect_true(result.has_key?('config_server'))
    config_server = result['config_server']
    expect_true(config_server.has_key?('server_type'))
    expect_true(config_server.has_key?('servers'))
    expect_true(config_server.has_key?('dbname'))
  end

  test 'get_empty_apps' do
    result = client.application_names
    expect_true(result.empty?)
  end

  test 'create_test_app' do
    result = client.create_application(app_name)
    # no exception
    assert_true(result)
  end

  test 'get_apps' do
    result = client.create_application(app_name)
    expect_equal([app_name], client.application_names)
    expect_equal({}, result.status)
  end

  test 'create_test_app_again' do
    client.create_application(app_name)
    assert_error(RuntimeError) { # TODO: message check
      client.create_application(app_name)
    }
  end

  test 'delete_test_app' do
    client.create_application(app_name)
    client.delete_application(app_name)
    result = client.application_names
    assert_true(result.empty?)

    # create again
    client.create_application(app_name)
    result = client.application_names
    expect_equal([app_name], result)
  end

  test 'delete_unknown_app' do
    assert_error(RuntimeError) {
      client.delete_application('unknown')
    }
  end
end

=begin
$num_training_data = 0;

TestCase 'Bazil-server save and load' do
  beforeCase do
    set :model_name, 'random'
    set :model_body, {'model_name' => model_name,
      'config' => {
        'converter_config' => JSON.parse(File.read(CONFIG_PATH)),
        'classifier_config' => {
          'method' => 'nherd',
          'regularization_weight' => 0.2
        }
      }
    }.to_json
  end
  before &setup_environment
  before &test_app_creation
  before &classification_tool

  after &test_app_deletion
  after &cleanup_environment

  test 'save' do
    result = JSON.parse(post.call(model_body, "/apps/#{app_name}/models").body)
    assert_equal("Created '#{model_name}' model", result['message'])

    train_data, classify_data = gen_data.call('random')
    train_data.each { |random_data|
      result = post.call(random_data.to_json, "/apps/#{app_name}/models/#{model_name}/training_data", {}).code.to_i
      abort_global_if(true) unless result == 200
    }
    $num_training_data += train_data.size
    assert_true(classify.call(classify_data) > 95)

    result = JSON.parse(post.call(model_body, "/apps/#{app_name}/save", {}).body)
    assert_equal("Saved '#{model_name}' model", result['message'])

    expect_true(FileTest.exist?(File.join(EXPORT_DIR, "#{app_name}-#{model_name}-1.meta")))
    expect_true(FileTest.exist?(File.join(EXPORT_DIR, "#{app_name}-#{model_name}-1.model")))

    # TODO: check md5sum and file size
  end

  test 'load' do
    next # currently disabled due to the change of the specification

    # Above 'save' test stores meta and model files to EXPORT_DIR
    result = JSON.parse(post.call(model_body, "/apps/#{app_name}/load", {}).body)
    expect_equal("Loaded '#{model_name}' model, revision 1", result['message'])

    result = JSON.parse(get.call("/apps/#{app_name}/models"))
    expect_equal([model_name], result['model_names'])

    _, classify_data = gen_data.call('random')
    assert_true(classify.call(classify_data) > 95)

    status = JSON.parse(get.call("/apps/#{app_name}/models/#{model_name}/status"))
    expect_equal($num_training_data, status['num_training_data'])
    expect_equal(1000, status['num_train_queries'])
    expect_equal(200, status['num_queries'])
    expect_equal(10, status['num_features'])  # maybe
    expect_equal(2, status['num_labels'])  # maybe
    expect_equal(1, status['revision'])  # maybe
  end

  # TODO: seprate test to new TestCase
  test 'save_and_load_with_revisioned_config' do
    result = JSON.parse(post.call(model_body, "/apps/#{app_name}/models").body)
    assert_equal("Created '#{model_name}' model", result['message'])

    # Save
    classifier_config = {'classifier_config' => {'method' => 'arow'}}
    result = JSON.parse(put.call(classifier_config.to_json, "/apps/#{app_name}/models/#{model_name}").body)
    result = JSON.parse(get.call("/apps/#{app_name}/models/#{model_name}/config"))
    result_cc = result['classifier_config']
    expect_equal('arow', result_cc['method'])
    expect_equal(2, result['revision'])

    result = JSON.parse(post.call(model_body, "/apps/#{app_name}/save", {}).body)
    assert_equal("Saved '#{model_name}' model", result['message'])
    expect_true(FileTest.exist?(File.join(EXPORT_DIR, "#{app_name}-#{model_name}-1.meta")))
    expect_true(FileTest.exist?(File.join(EXPORT_DIR, "#{app_name}-#{model_name}-1.model")))

    # Load
    result = JSON.parse(post.call(model_body, "/apps/#{app_name}/load", {}).body)
    expect_equal("Loaded '#{model_name}' model, revision 1", result['message'])
    result = JSON.parse(get.call("/apps/#{app_name}/models"))
    expect_equal([model_name], result['model_names'])

    result = JSON.parse(get.call("/apps/#{app_name}/models/#{model_name}/config"))
    result_cc = result['classifier_config']
    assert_equal('arow', result_cc['method'])
    assert_equal(2, result['revision'])
  end
end

=end

