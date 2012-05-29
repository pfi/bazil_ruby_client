require 'rubygems'
require 'json'

require 'test_helper'
require 'bazil'

TestCase 'Bazil-server train and query' do
  include_context 'bazil_case_utils'
  include_context 'bazil_model_utils'
  include_context 'model_train_and_query_api'

  beforeCase { setup_environment }
  before {
    create_default_application
    create_random_model
  }

  after {
    delete_random_model
    delete_default_application
  }
  afterCase { cleanup_environment }

  test 'get_configs_ids' do
    result = model.config_ids
    expect_equal(1, result.size)
    expect_true(result.include?(model_config_id))
  end

  test 'get_unknown_config' do
    assert_error(RuntimeError) { # TODO: check message
      model.config('owkn')
    }
  end

  test 'get_config' do
    result = model.config(model_config_id)

    expect_equal('nherd', result['method'])
    expect_equal('saitama configuration', result['description'])
    result_cc = result['config']['classifier_config']
    expect_true((0.1..0.3).include?(result_cc['regularization_weight'])) # cannot check equality because to string changes float value
  end

  test 'delete_config' do
    result = model.delete_config(model_config_id)
    expect_true(result)
    expect_true(model.config_ids.empty?)
    assert_error(RuntimeError) { # TODO: check message
      model.config(model_config_id)
    }
  end

  test 'update_with_invalid_config', :params => ['', '{', '1234', '"D"', "{'config' => []}",
                                                 "{'config' => {'classifier_config' => []}}"] do
    assert_error(RuntimeError) { # TODO: check message
      result = model.update_config(param, model_config_id)
    }
  end

  test 'update_method_config' do
    new_config = {
      'method' => 'arow'
    }

    result = model.update_config(new_config, model_config_id)
    expect_true(result)

    result = model.config(model_config_id)
    expect_equal('arow', result['method'])
  end

  test 'update_classifier_config' do
    new_config = {
      'config' => {
        'classifier_config' => {
          'regularization_weight' => 0.4
        }
      }
    }

    result = model.update_config(new_config, model_config_id)
    expect_true(result)

    result = model.config(model_config_id)
    result_cc = result['config']['classifier_config']
    expect_true((0.3..0.5).include?(result_cc['regularization_weight'])) # See 'get_config' test
  end

  test 'create_new_config' do
    new_config = model_config['model_config'].clone
    new_config['description'] = 'gunma is flontier'

    result = model.create_config('gunma', new_config)
    expect_equal('gunma', result['id'])

    result = model.config_ids
    expect_equal(2, result.size)
    expect_true(result.include?('gunma'))

    result = model.config('gunma')
    expect_equal('nherd', result['method'])
    expect_equal('gunma is flontier', result['description'])
    result_cc = result['config']['classifier_config']
    expect_true((0.1..0.3).include?(result_cc['regularization_weight'])) # See 'get_config' test
  end

  test 'create_new_config_without_id' do
    new_config = model_config['model_config'].clone
    new_config['description'] = 'temporary'

    result = model.create_config(nil, new_config)
    expected_id = Time.now.strftime("%Y%m%d%H")
    expect_equal(expected_id, result['id'][0...expected_id.size])
    expect_equal('temporary', result['description'])
  end

  test 'clone_config' do
    result = model.clone_config('owkn', {'description' => 'saitama?'}, model_config_id)
    base = model.config(model_config_id)

    expect_equal(2, model.config_ids.size)
    expect_equal('owkn', result['id'])
    expect_equal('saitama?', result['description'])
    expect_equal(base['config'], result['config'])
  end

  test 'clone_config_without_id' do
    result = model.clone_config(nil, {'method' => 'arow'}, model_config_id)
    base = model.config(model_config_id)

    assert_equal(2, model.config_ids.size)
    expected_id = Time.now.strftime("%Y%m%d%H")
    expect_equal(expected_id, result['id'][0...expected_id.size])
    expect_equal('arow', result['method'])
    assert_equal(base['config'], result['config'])
  end

  test 'clone_config_with_same_id' do
    assert_error(RuntimeError) { # TODO: check message
      model.clone_config(model_config_id, {'method' => 'arow'}, model_config_id)
    }
  end
end

=begin
TestCase 'Bazil-server config' do
  beforeCase &setup_environment
  before &test_app_creation
  before &random_model_creation

  after &random_model_deletion
  after &test_app_deletion
  afterCase &cleanup_environment

  test 'post_config' do
    collection = Mongo::Connection.new(*MONGODB_SERVERS.split(':')).db('bazil').collection('model_config')
    expect_equal(1, collection.find({'model' => "#{app_name}.#{model_name}"}).to_a.size)

    result = JSON.parse(post.call({'id' => 'saitama', 'description' => 'invalid'}.to_json, "/apps/#{app_name}/models/#{model_name}/config").body)
    expect_equal('saitama', result['id'])
    expect_equal('invalid', result['description'])

    expect_equal(2, collection.find({'model' => "#{app_name}.#{model_name}"}).to_a.size)
    expect_equal('saitama', JSON.parse(get.call("/apps/#{app_name}/models/#{model_name}/config/saitama"))['id'])
  end

  test 'replace_current_config' do
    [['saitama', 'invalid'], ['dasaitama', 'valid'], ['gunma', 'treasure']].each { |id, desc|
      result = JSON.parse(post.call({'id' => id, 'description' => desc}.to_json, "/apps/#{app_name}/models/#{model_name}/config").body)
      assert_equal(id, result['id'])
      assert_equal(desc, result['description'])
    }

    result = JSON.parse(put.call({'id' => 'saitama'}.to_json, "/apps/#{app_name}/models/#{model_name}/config").body)
    expect_equal('gunma', result['from'])
    expect_equal('saitama', result['to'])
    result = JSON.parse(put.call({'id' => 'gunma'}.to_json, "/apps/#{app_name}/models/#{model_name}/config").body)
    expect_equal('saitama', result['from'])
    expect_equal('gunma', result['to'])
    result = JSON.parse(put.call({'id' => 'dasaitama'}.to_json, "/apps/#{app_name}/models/#{model_name}/config").body)
    expect_equal('gunma', result['from'])
    expect_equal('dasaitama', result['to'])
  end

  test 'get_all_config' do
    [['saitama', 'invalid'], ['dasaitama', 'valid'], ['gunma', 'treasure']].each { |id, desc|
      result = JSON.parse(post.call({'id' => id, 'description' => desc}.to_json, "/apps/#{app_name}/models/#{model_name}/config").body)
      assert_equal(id, result['id'])
      assert_equal(desc, result['description'])
    }

    result = JSON.parse(post.call({'version' => 1}.to_json, "/apps/#{app_name}/models/#{model_name}/config/query").body)
    expect_equal(4, result['config'].size)
    expect_equal(4, result['total'])
    expect_equal(1, result['max_page'])
  end
  # TODO: add update_converter_config
end

TestCase 'Bazil-server config-query' do
  beforeCase &setup_environment
  before &test_app_creation
  before &random_model_creation
  before do
    [['saitama', 'invalid'], ['dasaitama', 'valid'], ['gunma', 'treasure']].each { |id, desc|
      result = JSON.parse(post.call({'id' => id, 'description' => desc}.to_json, "/apps/#{app_name}/models/#{model_name}/config").body)
      assert_equal(id, result['id'])
      assert_equal(desc, result['description'])
    }
  end

  after &random_model_deletion
  after &test_app_deletion
  afterCase &cleanup_environment

  test 'query_without_version' do
    result = JSON.parse(post.call({}.to_json, "/apps/#{app_name}/models/#{model_name}/config/query").body)
    expect_true(result.has_key?('errors'))
  end

  test 'all_query_with_id' do
    query = {'version' => 1, 'id' => {'all' => [{'pattern' => '.*ma$'}]}}
    result = JSON.parse(post.call(query.to_json, "/apps/#{app_name}/models/#{model_name}/config/query").body)
    expect_equal(3, result['total'])

    query = {'version' => 1, 'id' => {'all' => [{'pattern' => '.*ma$'}, {'pattern' => '^sa.*'}]}}
    result = JSON.parse(post.call(query.to_json, "/apps/#{app_name}/models/#{model_name}/config/query").body)
    expect_equal(1, result['total'])
  end

  test 'any_query_with_id' do
    query = {'version' => 1, 'id' => {'any' => [{'pattern' => '.*ma$'}]}}
    result = JSON.parse(post.call(query.to_json, "/apps/#{app_name}/models/#{model_name}/config/query").body)
    expect_equal(3, result['total'])

    query = {'version' => 1, 'id' => {'any' => [{'pattern' => 'gunma'}, {'pattern' => 'saitama'}]}}
    result = JSON.parse(post.call(query.to_json, "/apps/#{app_name}/models/#{model_name}/config/query").body)
    expect_equal(2, result['total'])
  end

  test 'and_and_any_query_with_id' do
    query = {'version' => 1, 'id' => {'all' => [{'pattern' => 'dasaitama'}], 'any' => [{'pattern' => 'gunma'}]}}
    result = JSON.parse(post.call(query.to_json, "/apps/#{app_name}/models/#{model_name}/config/query").body)
    expect_equal(2, result['total'])
  end

  test 'not_query_with_id' do
    query = {'version' => 1, 'id' => {'all' => [{'pattern' => '.*ma$'}], 'not' => [{'pattern' => 'gunma'}]}}
    result = JSON.parse(post.call(query.to_json, "/apps/#{app_name}/models/#{model_name}/config/query").body)
    expect_equal(2, result['total'])

    query = {'version' => 1, 'id' => {'any' => [{'pattern' => '.*ma$'}], 'not' => [{'pattern' => 'gunma'}]}}
    result = JSON.parse(post.call(query.to_json, "/apps/#{app_name}/models/#{model_name}/config/query").body)
    expect_equal(2, result['total'])
  end

  # deescription

  test 'all_query_with_description' do
    query = {'version' => 1, 'description' => {'all' => [{'pattern' => '.*a.*'}]}}
    result = JSON.parse(post.call(query.to_json, "/apps/#{app_name}/models/#{model_name}/config/query").body)
    expect_equal(3, result['total'])

    query = {'version' => 1, 'description' => {'all' => [{'pattern' => '.*a.*'}, {'pattern' => '^in.*'}]}}
    result = JSON.parse(post.call(query.to_json, "/apps/#{app_name}/models/#{model_name}/config/query").body)
    expect_equal(1, result['total'])
  end

  test 'any_query_with_description' do
    query = {'version' => 1, 'description' => {'any' => [{'pattern' => '.*a.*'}]}}
    result = JSON.parse(post.call(query.to_json, "/apps/#{app_name}/models/#{model_name}/config/query").body)
    expect_equal(3, result['total'])

    query = {'version' => 1, 'description' => {'any' => [{'pattern' => 'valid'}, {'pattern' => 'invalid'}]}}
    result = JSON.parse(post.call(query.to_json, "/apps/#{app_name}/models/#{model_name}/config/query").body)
    expect_equal(2, result['total'])
  end

  test 'and_and_any_query_with_description' do
    query = {'version' => 1, 'description' => {'all' => [{'pattern' => 'invalid'}], 'any' => [{'pattern' => 'treasure'}]}}
    result = JSON.parse(post.call(query.to_json, "/apps/#{app_name}/models/#{model_name}/config/query").body)
    expect_equal(2, result['total'])
  end

  test 'not_query_with_description' do
    query = {'version' => 1, 'description' => {'all' => [{'pattern' => '.*a.*'}], 'not' => [{'pattern' => 'treasure'}]}}
    result = JSON.parse(post.call(query.to_json, "/apps/#{app_name}/models/#{model_name}/config/query").body)
    expect_equal(2, result['total'])

    query = {'version' => 1, 'description' => {'any' => [{'pattern' => '.*a.*'}], 'not' => [{'pattern' => '.*valid'}]}}
    result = JSON.parse(post.call(query.to_json, "/apps/#{app_name}/models/#{model_name}/config/query").body)
    expect_equal(1, result['total'])
  end

  # TODO: Add sort and more complex test
end
=end
