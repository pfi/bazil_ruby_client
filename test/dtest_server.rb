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

TestCase 'Bazil-server training-data-query-field-sort' do
  beforeCase &setup_environment
  before &test_app_creation
  before &random_model_creation

  after &random_model_deletion
  after &test_app_deletion
  afterCase &cleanup_environment

  before do
    set :add_training_data, Proc.new {
      i = 1

      # data with label
      [['D', ['god', 10]], ['C++', ['owkn', -1]], ['C#', ['normal', 1000]]].each { |label, value|
        training_data = {'f1' => value[0], 'f2' => value[1]}
        result = JSON.parse(post.call({'label' => label, 'data' => training_data}.to_json, "/apps/#{app_name}/models/#{model_name}/training_data").body)
        assert_equal(i, result['id'])
        i += 1
      }

      $num_training_data += i - 1

      i - 1
    }
  end

  test 'asc', :params => ['f1', 'f2'] do
    add_training_data.call()

    sort_conditions = [{'target' => 'field', 'key' => param, 'asc' => true}]
    query = {'version' => 1, 'sort' => sort_conditions}
    result = JSON.parse(post.call(query.to_json, "/apps/#{app_name}/models/#{model_name}/training_data/query").body)['training_data'].map { |e| e['data'] }
    result.each_cons(2) { |a, b|
      expect_true(a[param] < b[param])
    }
  end

  test 'desc', :params => ['f1', 'f2'] do
    add_training_data.call()

    sort_conditions = [{'target' => 'field', 'key' => param, 'asc' => false}]
    query = {'version' => 1, 'sort' => sort_conditions}
    result = JSON.parse(post.call(query.to_json, "/apps/#{app_name}/models/#{model_name}/training_data/query").body)['training_data'].map { |e| e['data'] }
    result.each_cons(2) { |a, b|
      expect_true(a[param] > b[param])
    }
  end

  test 'missing_key_field' do
    add_training_data.call()

    sort_conditions = [{'target' => 'field', 'asc' => false}]
    query = {'version' => 1, 'sort' => sort_conditions}
    result = JSON.parse(post.call(query.to_json, "/apps/#{app_name}/models/#{model_name}/training_data/query").body)
    expect_true(result.has_key?('errors'));
  end
end

TestCase 'Bazil-server training-data-query-sort' do
  beforeCase &setup_environment
  before &test_app_creation
  before &random_model_creation

  after &random_model_deletion
  after &test_app_deletion
  afterCase &cleanup_environment

  before do
    set :float_key, 'float'
    set :int_key, 'int'
    set :str_key, 'str'
    set :add_training_data_for_sort, Proc.new {
      i = 1

      [-0.5, 1.0, 0.0, -10.5, 1.0, 1.5].zip([100, 0, -1000, 100, 50, 100], ['a', 'led', 'z', 'z', 'red', 'b']) { |f, n, s|
        training_data = {float_key => f, 'int' => n, 'str' => s}
        result = JSON.parse(post.call({'label' => 'sort', 'data' => training_data}.to_json, "/apps/#{app_name}/models/#{model_name}/training_data").body)
        assert_equal(i, result['id'])
        i += 1
      }

      $num_training_data += i - 1
    }
    set :sort_checker, Proc.new { |sort_conditions|
      query = {'version' => 1, 'field' => {'str' => {'any' => [{'pattern' => '.*'}]}}, 'sort' => sort_conditions}
      result = JSON.parse(post.call(query.to_json, "/apps/#{app_name}/models/#{model_name}/training_data/query").body)['training_data'].map { |e| e['data'] }
      result.each_cons(2) { |a, b|
        num = 1
        check = sort_conditions.any? { |sort_condition|
          key = sort_condition['key']
          cond = sort_condition['asc'] ? :< : :>
          if a[key].__send__(cond, b[key])
            true
          elsif a[key] == b[key]
            if num == sort_conditions.size
              true
            else
              num += 1
              false # goto next comparison
            end
          else
            break false
          end
        }
        expect_true(check)
      }
    }
  end

  test 'query_with_one_key_sort' do
    add_training_data_for_sort.call()

    [float_key, int_key, str_key].each { |key|
      [true, false].each { |asc|
        sort_checker.call([{'target' => 'field', 'key' => key, 'asc' => asc}])
      }
    }
  end

  test 'query_with_two_keys_sort' do
    add_training_data_for_sort.call()

    conds = [true, false].repeated_permutation(2).to_a
    [float_key, int_key, str_key].permutation(2).each { |key1, key2|
      conds.each { |asc1, asc2|
        sort_checker.call([{'target' => 'field', 'key' => key1, 'asc' => asc1}, {'target' => 'field', 'key' => key2, 'asc' => asc2}])
      }
    }
  end

  test 'query_with_three_keys_sort' do
    add_training_data_for_sort.call()

    conds = [true, false].repeated_permutation(3).to_a
    [float_key, int_key, str_key].permutation(3).each { |key1, key2, key3|
      conds.each { |asc1, asc2, asc3|
        sort_checker.call([{'target' => 'field', 'key' => key1, 'asc' => asc1}, {'target' => 'field', 'key' => key2, 'asc' => asc2}, {'target' => 'field', 'key' => key3, 'asc' => asc3}])
      }
    }
  end

  test 'label_and_id_asc_sort' do
    add_training_data_for_sort.call()

    sort_conditions = [{'target' => 'label', 'key' => '', 'asc' => true}, {'target' => 'id', 'key' => '', 'asc' => true}]
    query = {'version' => 1, 'sort' => sort_conditions}
    result = JSON.parse(post.call(query.to_json, "/apps/#{app_name}/models/#{model_name}/training_data/query").body)['training_data'].map { |e| e['id'] }
    result.each_cons(2) { |a, b|
      expect_true(a < b)
    }
  end

  test 'label_and_id_desc_sort' do
    add_training_data_for_sort.call()

    sort_conditions = [{'target' => 'label', 'key' => '', 'asc' => true}, {'target' => 'id', 'key' => '', 'asc' => false}]
    query = {'version' => 1, 'sort' => sort_conditions}
    result = JSON.parse(post.call(query.to_json, "/apps/#{app_name}/models/#{model_name}/training_data/query").body)['training_data'].map { |e| e['id'] }
    result.each_cons(2) { |a, b|
      expect_true(a > b)
    }
  end
end

TestCase 'Bazil-server train and query' do
  beforeCase &setup_environment
  before &test_app_creation
  before &random_model_creation
  before do
    set :gen_data, lambda { |algorithm|
      sample = `#{File.join(BUILD_PATH, 'gen_uniform_distribution')} #{algorithm}`.split("\n").map { |e| JSON.parse(e) }
      train_data = sample[0...1000]
      classify_data = sample[1000..-1]
      [train_data, classify_data]
    }
  end

  after &random_model_deletion
  after &test_app_deletion
  afterCase &cleanup_environment

  test 'random_distribution' do
    train_data, classify_data = gen_data.call('random')

    train_data.each { |random_data|
      result = post.call(random_data.to_json, "/apps/#{app_name}/models/#{model_name}/training_data", {})
      abort_global_if(true) unless result.code.to_i == 200

      # Check GET /apps/app/models/model/training_data/id
      result_id = JSON.parse(result.body)["id"]
      train_data_id = JSON.parse(get.call("/apps/#{app_name}/models/#{model_name}/training_data/#{result_id}"))["id"]
      expect_equal(result_id, train_data_id)
    }
    $num_training_data += train_data.size

    collect_result = 0
    classify_data.each { |random_data|
      result = post.call(random_data['data'].to_json, "/apps/#{app_name}/models/#{model_name}/query", {}).body
      classified = JSON.parse(result);
      collect_result +=1 if random_data['label'] == classified['max_label']
    }

    expect_true(collect_result > 95)

    result = JSON.parse(get.call("/apps/#{app_name}/models/#{model_name}/labels"))
    assert_equal(["NG", "OK"], result['labels'].sort)

    status = JSON.parse(get.call("/apps/#{app_name}/models/#{model_name}/status"))
    expect_equal(1000, status['num_training_data'])
    expect_equal(1000, status['num_train_queries'])
    expect_equal(100, status['num_queries'])
    expect_equal(10, status['num_features'])  # maybe
    expect_equal(2, status['num_labels'])  # maybe
  end

  test 'random3_distribution' do
    train_data, classify_data = gen_data.call('random3')

    train_data.each { |random_data|
      result = post.call(random_data.to_json, "/apps/#{app_name}/models/#{model_name}/training_data", {}).code.to_i
      abort_global_if(true) unless result == 200
    }
    $num_training_data += train_data.size

    collect_result = 0
    classify_data.each { |random_data|
      result = post.call(random_data['data'].to_json, "/apps/#{app_name}/models/#{model_name}/query", {}).body
      classified = JSON.parse(result);
      collect_result +=1 if random_data['label'] == classified['max_label']
    }

    expect_true(collect_result > 95)

    result = JSON.parse(get.call("/apps/#{app_name}/models/#{model_name}/labels"))
    assert_equal(["1", "2", "3"], result['labels'].sort)

    status = JSON.parse(get.call("/apps/#{app_name}/models/#{model_name}/status"))
    expect_equal(1000, status['num_training_data'])
    expect_equal(1000, status['num_train_queries'])
    expect_equal(100, status['num_queries'])
    expect_equal(10, status['num_features'])  # maybe
    expect_equal(3, status['num_labels'])  # maybe
  end

  test 'train_with_invalid_data', :params => [nil, true, [1, 2], {'key' => 'value'}] do
    result = post.call({'label' => 'invalid', 'data' => {'k' => param}}.to_json, "/apps/#{app_name}/models/#{model_name}/training_data", {})
    expect_equal(500, result.code.to_i)
    expect_true(JSON.parse(result.body).has_key?('errors'))
  end
end

classification_tool = lambda {
  set :gen_data, lambda { |algorithm|
    sample = `#{File.join(BUILD_PATH, 'gen_uniform_distribution')} #{algorithm}`.split("\n").map { |e| JSON.parse(e) }
    train_data = sample[0...1000]
    classify_data = sample[1000..-1]
    [train_data, classify_data]
  }
  set :classify, lambda { |classify_data|
    collect_result = 0
    classify_data.each { |random_data|
      result = post.call(random_data['data'].to_json, "/apps/#{app_name}/models/#{model_name}/query", {}).body
      classified = JSON.parse(result);
      collect_result +=1 if random_data['label'] == classified['max_label']
    }
    collect_result
  }
}

TestCase 'Bazil-server retrain' do
  beforeCase &setup_environment
  before &test_app_creation
  before &random_model_creation
  before &classification_tool

  after &random_model_deletion
  after &test_app_deletion
  afterCase &cleanup_environment

  test 'random_distribution' do
    train_data, classify_data = gen_data.call('random')

    train_data.each { |random_data|
      result = post.call(random_data.to_json, "/apps/#{app_name}/models/#{model_name}/training_data", {}).code.to_i
      abort_global_if(true) unless result == 200
    }
    $num_training_data += train_data.size

    collect_result = classify.call(classify_data)
    expect_true(collect_result > 95)

    result = JSON.parse(post.call('', "/apps/#{app_name}/models/#{model_name}/retrain", {}).body)
    expect_true(result.has_key?('elapsed_time'))
    expect_true(train_data.size, result['total'])
    retrain_result = classify.call(classify_data)
    expect_equal(retrain_result, collect_result)

    result = JSON.parse(post.call('', "/apps/#{app_name}/models/#{model_name}/retrain", {}).body)
    assert_true(result.has_key?('elapsed_time'))
    assert_true(train_data.size, result['total'])
    retrain_result = classify.call(classify_data)
    expect_equal(retrain_result, collect_result)
  end

  test 'random_distribution with range' do
    train_data, classify_data = gen_data.call('random')

    train_data.each { |random_data|
      result = post.call(random_data.to_json, "/apps/#{app_name}/models/#{model_name}/training_data", {}).code.to_i
      abort_global_if(true) unless result == 200
    }
    $num_training_data += train_data.size

    collect_result = classify.call(classify_data)
    expect_true(collect_result > 95)

    result = JSON.parse(post.call({"from" => 100, "to" =>  400}.to_json, "/apps/#{app_name}/models/#{model_name}/retrain", {}).body)
    assert_true(result.has_key?('elapsed_time'))
    expect_true(300, result['total'])
    retrain_result = classify.call(classify_data)
    expect_equal(retrain_result, collect_result)

    result = JSON.parse(post.call({"from" => 700, "to" =>  800}.to_json, "/apps/#{app_name}/models/#{model_name}/retrain", {}).body)
    assert_true(result.has_key?('elapsed_time'))
    expect_true(100, result['total'])
    retrain_result = classify.call(classify_data)
    expect_equal(retrain_result, collect_result)
  end

  test 'random3_distribution' do
    train_data, classify_data = gen_data.call('random3')

    train_data.each { |random_data|
      result = post.call(random_data.to_json, "/apps/#{app_name}/models/#{model_name}/training_data", {}).code.to_i
      abort_global_if(true) unless result == 200
    }
    $num_training_data += train_data.size

    collect_result = classify.call(classify_data)
    expect_true(collect_result > 95)

    result = JSON.parse(post.call('', "/apps/#{app_name}/models/#{model_name}/retrain", {}).body)
    assert_true(result.has_key?('elapsed_time'))
    expect_true(train_data.size, result['total'])
    retrain_result = classify.call(classify_data)
    expect_equal(retrain_result, collect_result)

    result = JSON.parse(post.call('', "/apps/#{app_name}/models/#{model_name}/retrain", {}).body)
    assert_true(result.has_key?('elapsed_time'))
    assert_true(train_data.size, result['total'])
    retrain_result = classify.call(classify_data)
    expect_equal(retrain_result, collect_result)
  end
end

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

