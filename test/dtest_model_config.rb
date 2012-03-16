# This test will be activated after the specification of Model's revision management is fixed.

=begin
TestCase 'Bazil-server config' do
  beforeCase &setup_environment
  before &test_app_creation
  before &random_model_creation

  after &random_model_deletion
  after &test_app_deletion
  afterCase &cleanup_environment

  test 'get_config' do
    result = JSON.parse(get.call("/apps/#{app_name}/models/#{model_name}/config"))
    result_cc = result['config']['classifier_config']
    assert_equal('nherd', result_cc['method'])
    assert_equal('0.2', result_cc['regularization_weight'].to_s[0..2])
    expected_id = Time.now.strftime("%Y%m%d%H")
    expect_equal(expected_id, result['id'][0...expected_id.size])
    expect_equal('', result['description'])
  end

  test 'get_config_using_invalid_id', :params => ['---', 'ho$ge', 'id.json'] do
    assert_error(OpenURI::HTTPError) {
      get.call("/apps/#{app_name}/models/#{model_name}/config/#{param}")
    }
  end

  test 'get_config_using_id' do
    id = JSON.parse(get.call("/apps/#{app_name}/models/#{model_name}/config"))['id']
    result = JSON.parse(get.call("/apps/#{app_name}/models/#{model_name}/config/#{id}"))
    expect_equal(id, result['id'])
  end

  test 'post_config' do
    collection = Mongo::Connection.new(*MONGODB_SERVERS.split(':')).db('bazil').collection('model_config')
    expect_equal(1, collection.find({'model' => "#{app_name}.#{model_name}"}).to_a.size)

    result = JSON.parse(post.call({'id' => 'saitama', 'description' => 'invalid'}.to_json, "/apps/#{app_name}/models/#{model_name}/config").body)
    expect_equal('saitama', result['id'])
    expect_equal('invalid', result['description'])

    expect_equal(2, collection.find({'model' => "#{app_name}.#{model_name}"}).to_a.size)
    expect_equal('saitama', JSON.parse(get.call("/apps/#{app_name}/models/#{model_name}/config/saitama"))['id'])
  end

  test 'update_classifier_config' do
    classifier_config = {
      'classifier_config' => {
        'method' => 'arow',
        'regularization_weight' => 0.4
      }
    }

    result = JSON.parse(put.call(classifier_config.to_json, "/apps/#{app_name}/models/#{model_name}/config").body)
    expect_true(result.has_key?('message'))

    result = JSON.parse(get.call("/apps/#{app_name}/models/#{model_name}/config"))
    result_cc = result['config']['classifier_config']
    assert_equal('arow', result_cc['method'])
    assert_equal('0.4', result_cc['regularization_weight'].to_s[0..2])
  end

  test 'update_with_invalid_config', :params => ['', '{', '1234', '"D"'] do
    result = JSON.parse(put.call(param, "/apps/#{app_name}/models/#{model_name}/config").body)
    expect_true(result.has_key?('errors'))
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
