require 'rubygems'
require 'json'

require 'test_helper'
require 'bazil'

SharedContext 'training_data_query_test_util' do
  def prepare_training_data
    # add training data
    # string value data
    ['redbull', 'rockstar', 'coke'].each { |value|
      model.put_training_data({'string_feature' => value})
    }

    # number value data
    [500, 100_000, -1].each { |value|
      model.put_training_data({'num_feature' => value})
    }

    # data with annotation
    [['C#', ['net', 10]], ['C++', ['owkn', -1]], ['D', ['god', 1000]]].each { |annotation, value|
      model.train(annotation, {'feature1' => value[0], 'feature2' => value[1]})
    }

    set :training_data_size, get_training_data_size
  end
end

TestCase 'Bazil-server training-data-query annotation' do
  include_context 'bazil_case_utils'
  include_context 'bazil_model_utils'
  include_context 'training_data_query_test_util'

  beforeCase do
    setup_environment

    create_default_application
    create_random_model
    prepare_training_data
  end

  afterCase do
    delete_random_model
    delete_default_application
    cleanup_environment
  end

  test 'query_all' do
    result = model.list_training_data({})
    expect_equal(training_data_size, result['total'])

    # check default values
    expect_equal(1, result['page'])
    expect_equal(10, result['page_size'])
    expect_equal([10, training_data_size].min, result['training_data'].size)
    expect_equal((training_data_size + 10 - 1) / 10, result['max_page'])
    expect_true(result.has_key?('query'))
  end

  # TODO: activate this test
=begin
  test 'query_without_version' do
    query = {'annotation' => {'all' => [{'pattern' => '.*'}]}}
    result = JSON.parse(post.call(query.to_json, "/apps/#{app_name}/models/#{model_name}/training_data/query").body)
    expect_true(result.has_key?("errors"))
  end
=end

  test 'exist_query_with_annotation', :params => [[true, 3], [false, 6]] do
    query = {
      :annotation => {
        :exist => param[0]
      }
    }
    result = model.list_training_data({:query => query})

    expect_equal(param[1], result['training_data'].size)
  end

  test 'invalid_exist_query_with_annotation', :params => [nil, 1, 'test', [1, 2], {'key' => 'value'}] do
    query = {
      :annotation => {
        :exist => param
      }
    }

    assert_error(Bazil::APIError) { # TODO: make this Bazil::ListTrainingDataError
      model.list_training_data({:query => query})
    }
  end

  test 'all_query_with_annotation',
    :params => [[3, [{:pattern => '.*'}]],
                [1, [{:pattern => '^C.*'}, {:pattern => '^.\#$'}]],
                [0, [{:pattern => 'C#'}, {:pattern => 'C\+\+'}, {:pattern => 'D'}]]] do

    query = {:annotation => {:all => param[1]}}
    result = model.list_training_data({:query => query})
    expect_equal(param[0], result['training_data'].size)

    # TODO: Check this specific case
=begin
    query = {'version' => 1, 'annotation' => {'all' => }}
    result = JSON.parse(post.call(query.to_json, "/apps/#{app_name}/models/#{model_name}/training_data/query").body)
    expect_equal(1, result['training_data'].size)
    expect_equal('C#', result['training_data'][0]['annotation'])
=end
  end

  test 'specific_all_query_with_annotation' do
    query = {:annotation => {:all => [{:pattern => '^C.*'}, {:pattern => '^.\#$'}]}}
    result = model.list_training_data({:query => query})
    assert_equal(1, result['training_data'].size)
    expect_equal('C#', result['training_data'][0]['annotation'])
  end

  test 'all_query_with_annotation_with_page_size', :params => (1..3).to_a do
    annotated_training_data_size = 3
    query = {:version => 1, :annotation => {:all => [{:pattern => '.*'}]}}
    result = model.list_training_data({:page_size => param, :query => query})
    expect_equal(param, result['training_data'].size)
    expect_equal((annotated_training_data_size + param - 1) / param, result['max_page'])
  end

  test 'all_query_with_annotation_with_page_and_page_size', :params => combine([1, 2, 3], [1, 2, 3]) do # [page, page_size]
    page = param[0]
    page_size = param[1]
    annotated_training_data_size = 3

    query = {:annotation => {:all => [{:pattern => '.*'}]}}
    result = model.list_training_data({:page => page, :page_size => page_size, :query => query})

    expected_training_data_size = [[0, annotated_training_data_size - page_size * (page - 1)].max,
                                   page_size].min
    expected_max_page = (annotated_training_data_size + page_size - 1) / page_size

    expect_equal(annotated_training_data_size, result['total'])
    expect_equal(expected_training_data_size, result['training_data'].size)
    expect_equal(expected_max_page, result['max_page'])
  end

  test '0_hit_all_query_with_annotation' do
    query = {:annotation => {:all => [{:pattern => 'unknownn'}]}}
    result = model.list_training_data({:query => query})
    expect_equal(0, result['training_data'].size)
    expect_equal(0, result['total'])
    expect_equal(0, result['max_page'])
  end

  test 'any_query_with_annotation',
    :params => [[['.*'], 3, ['D', 'C#', 'C++']],
                [['^.$', '^..$'], 2, ['D', 'C#']],
                [['^.$', '^..$', '...'], 3, ['D', 'C#', 'C++']]] do
    query = {:version => 1, :annotation => {:any => param[0].map {|p| {:pattern => p}}}}
    result = model.list_training_data({:query => query})
    expect_equal(param[1], result['training_data'].size)
    result['training_data'].each {|d|
      expect_true(param[2].include?(d['annotation']))
    }
  end

  test 'all_or_any_query_with_annotation_using_partial_match', :params => ['any', 'all'] do
    query = {:annotation => {param => [{:pattern => 'C'}]}}
    result = model.list_training_data({:query => query})
    expect_equal(2, result['training_data'].size)
    expect_equal(2, result['total'])
    expect_equal(1, result['max_page'])
  end

  test 'all_and_any_query_with_annotation' do
    annotations = ['D', 'C++']
    query = {:annotation => {:all => [{:pattern => '^.$'}], :any => [{:pattern => '...'}]}}
    result = model.list_training_data({:query => query})
    expect_equal(2, result['training_data'].size)
    expect_true(annotations.include?(result['training_data'][0]['annotation']))
    expect_true(annotations.include?(result['training_data'][1]['annotation']))
  end

  test 'all_and_not_query_with_annotation' do
    query = {:annotation => {:all => [{:pattern => '.*'}], :not => [{:pattern => 'D'}]}}
    result = model.list_training_data({:query => query})
    expect_equal(2, result['training_data'].size)
    # TODO: check include?
  end

  test 'any_and_not_query_with_annotation' do
    query = {'version' => 1, 'annotation' => {'any' => [{'pattern' => '.*'}], 'not' => [{'pattern' => 'D'}]}}
    result = model.list_training_data({:query => query})
    expect_equal(2, result['training_data'].size)
    # TODO: check include?
  end

  test 'and_and_any_and_not_query_with_annotation' do
    query = {'version' => 1, 'annotation' => {'all' => [{'pattern' => '^.$'}], 'any' => [{'pattern' => '...'}], 'not' => [{'pattern' => 'D'}]}}
    result = model.list_training_data({:query => query})
    expect_equal(1, result['training_data'].size)
    expect_equal('C++', result['training_data'][0]['annotation'])
  end
end

TestCase 'Bazil-server training-data-query field' do
  include_context 'bazil_case_utils'
  include_context 'bazil_model_utils'
  include_context 'training_data_query_test_util'

  beforeCase do
    setup_environment

    create_default_application
    create_random_model
    prepare_training_data
  end

  afterCase do
    delete_random_model
    delete_default_application
    cleanup_environment
  end

  test 'exist_query_with_field', :params => combine([['string_feature', 3], ['num_feature', 3], ['feature1', 3], ['feature2', 3]], [true, false]) do
    exist = param[2]
    query = {:version => 1, :field =>
      {
        param[0] => {:exist => exist}
      }
    }
    result = model.list_training_data({:query => query})
    expect_equal(exist ? param[1] : training_data_size - param[1], result['training_data'].size)
  end

  test 'all_query_with_field_pattern_single' do
    query = {:version => 1, :field =>
      {
        'string_feature' => {:all => [{:pattern => '.*'}]}
      }
    }
    result = model.list_training_data({:query => query})
    expect_equal(3, result['training_data'].size)
  end

  test 'all_query_with_field_pattern_multi' do
    query = {:version => 1, :field =>
      {
        'string_feature' => {:all => [{:pattern => '^r.*'}, {:pattern => '.*l$'}]}
      }
    }
    result = model.list_training_data({:query => query})
    expect_equal(1, result['training_data'].size)
    expect_equal('redbull', result['training_data'][0]['data']['string_feature'])
  end

  test 'all_query_with_range_pattern_single' do
    query = {:version => 1, :field =>
      {
        'num_feature' => {:all => [{:range => {:from => -100_000, :to => 100_000}}]}
      }
    }
    result = model.list_training_data({:query => query})
    expect_equal(3, result['training_data'].size)
  end

  test 'all_query_with_range_pattern_multi' do
    query = {:version => 1, :field =>
      {
        'num_feature' => {:all => [{:range => {:from => -100, :to => 1000}}, {:range => {:from => 200, :to => 1000}}]}
      }
    }
    result = model.list_training_data({:query => query})
    expect_equal(1, result['training_data'].size)
    expect_equal(500, result['training_data'][0]['data']['num_feature'])
  end

  test 'all_query_with_exact_range_pattern' do
    query = {:version => 1, :field =>
      {
        'num_feature' => {:all => [{:range => {:from => 100_000, :to => 100_000}}]}
      }
    }
    result = model.list_training_data({:query => query})
    expect_equal(1, result['training_data'].size)
    expect_equal(100_000, result['training_data'][0]['data']['num_feature'])
  end

  test 'any_query_with_field_pattern_single' do
    query = {:version => 1, :field =>
      {
        'string_feature' => {:any => [{:pattern => '.*'}]}
      }
    }
    result = model.list_training_data({:query => query})
    expect_equal(3, result['training_data'].size)
  end

  test 'any_query_with_field_pattern_multi' do
    query = {:version => 1, :field =>
      {
        'string_feature' => {:any => [{:pattern => '^ro.*'}, {:pattern => '^c.*'}]}
      }
    }
    result = model.list_training_data({:query => query})
    expect_equal(2, result['training_data'].size)
  end

  test 'any_query_with_range_pattern_single' do
    query = {:version => 1, :field =>
      {
        'num_feature' => {:any => [{:range => {:from => -100_000, :to => 100_000}}]}
      }
    }
    result = model.list_training_data({:query => query})
    expect_equal(3, result['training_data'].size)
  end

  test 'any_query_with_range_pattern_multi' do
    query = {:version => 1, :field =>
      {
        'num_feature' => {:any => [{:range => {:from => -100, :to => 1000}}, {:range => {:from => 200, :to => 1000}}]}
      }
    }
    result = model.list_training_data({:query => query})
    expect_equal(2, result['training_data'].size)
  end

  test 'all_and_not_query_with_field_pattern' do
    query = {:version => 1, :field =>
      {
        'string_feature' => {:all => [{:pattern => '.*'}], :not => [{:pattern => '^c.*'}]}
      }
    }
    result = model.list_training_data({:query => query})
    expect_equal(2, result['training_data'].size)
  end

  test 'any_and_not_query_with_field_pattern' do
    query = {:version => 1, :field =>
      {
        'num_feature' => {:all => [{:range => {:from => -100_000, :to => 100_000}}], :not => [{:range => {:from => -1, :to => -1}}]}
      }
    }
    result = model.list_training_data({:query => query})
    expect_equal(2, result['training_data'].size)
  end

  # TODO: all_and_any_query
  # TODO: all_and_any_and_not_query

  test 'all_and_any_query_with_two_fields' do
    query = {:version => 1, :field =>
      {
        'feature1' => {:all => [{:pattern => '.*'}]},
        'feature2' => {:any => [{:range => {:from => 500, :to => 1000}}]}
      }
    }
    result = model.list_training_data({:query => query})
    expect_equal(1, result['training_data'].size)
    expect_equal('D', result['training_data'][0]['annotation'])
  end

  test 'all_and_exist_query_with_two_fields' do
    query = {:version => 1, :field =>
      {
        'feature1' => {:all => [{:pattern => '.*'}]},
        'feature2' => {:exist => true}
      }
    }
    result = model.list_training_data({:query => query})
    expect_equal(3, result['training_data'].size)
  end

  test 'any_and_exist_query_with_two_fields' do
    query = {:version => 1, :field =>
      {
        'feature1' => {:all => [{:pattern => '.*'}]},
        'feature2' => {:exist => false}
      }
    }
    result = model.list_training_data({:query => query})
    expect_equal(0, result['training_data'].size)
  end

  test 'all_and_empty_query_with_two_fields' do
    query = {:version => 1, :field =>
      {
        'feature1' => {:all => [{:pattern => '^r.*'}, {:pattern => '.*l$'}]}, # hit 0
        'feature2' => {} # hit all
      }
    }
    result = model.list_training_data({:query => query})
    expect_equal(0, result['training_data'].size)
  end

  # TODO: add more patterns

  test 'query_with_empty_condition_1' do
    query = {'version' => 1, 'field' =>
      {
        'feature1' => {'all' => [{'pattern' => '.*'}]},
        'feature2' => {}
      }
    }
    result = model.list_training_data({:query => query})
    expect_equal(3, result['training_data'].size)
  end

  test 'query_with_empty_condition_2' do
    query = {'version' => 1, 'field' =>
      {
        'feature2' => {},
        'feature1' => {'all' => [{'pattern' => '.*'}]}
      }
    }
    result = model.list_training_data({:query => query})
    expect_equal(3, result['training_data'].size)
  end

  test 'query_with_annotation_and_field_1' do
    query = {:version => 1, 
      :field => {
        'feature2' => {:any => [{:range => {:from => 0, :to => 100}}]}
      },
      :annotation => {
        :all => [{:pattern => '^C.*'}]
      }
    }
    result = model.list_training_data({:query => query})
    expect_equal(1, result['training_data'].size)
    expect_equal('C#', result['training_data'][0]['annotation'])
  end

  test 'query_with_annotation_and_field_2' do
    query = {:version => 1,
      :field => {
        'feature2' => {:any => [{:range => {:from => -100, :to => 0}}]}
      },
      :annotation => {
        :all => [{:pattern => '^C.*'}]
      }
    }
    result = model.list_training_data({:query => query})
    expect_equal(1, result['training_data'].size)
    expect_equal('C++', result['training_data'][0]['annotation'])
  end

  test 'query_with_annotation_and_field_3' do
    query = {:version => 1,
      :field => {
        'feature2' => {:any => [{:range => {:from => 0, :to => 10000}}]}
      },
      :annotation => {
        :all => [{:pattern => '^.$'}]
      }
    }
    result = model.list_training_data({:query => query})
    expect_equal(1, result['training_data'].size)
    expect_equal('D', result['training_data'][0]['annotation'])
  end

  test 'query_with_annotation_and_field', :params => [{'version' => 1}, {'version' => 1, 'annotation' => {}, 'field' => {}},
                                                 {'version' => 1, 'annotation' => {}}, {'version' => 1, 'field' => {}}] do
    result = model.list_training_data({:query => param})
    expect_equal(9, result['training_data'].size)
    expect_equal(9, result['total'])
  end

  test 'asterisk_query_with_field_pattern' do
    query = {:version => 1,
      '*' => {
         :any => [{:pattern => 'god'}]
      }
    }
    model.list_training_data({:query => query}) # no exception
  end

  test 'asterisk_query_with_range_pattern' do
    query = {:version => 1,
      '*' => {
         :all => [{:range => {:from => -10, :to => 10}}]
      }
    }
    model.list_training_data({:query => query}) # no exception
  end

  # TODO: add a lot more invalid quries
end

TestCase 'Bazil-server training-data-query id' do
  include_context 'bazil_case_utils'
  include_context 'bazil_model_utils'
  include_context 'training_data_query_test_util'

  beforeCase do
    setup_environment

    create_default_application
    create_random_model
    prepare_training_data
  end

  afterCase do
    delete_random_model
    delete_default_application
    cleanup_environment
  end

  test 'query_all_with_id' do
    query = {:version => 1,
      'id' => {
        'from' => 1, 'to' => 100
      }
    }
    result = model.list_training_data({:query => query})
    expect_equal(training_data_size, result['total'])
  end

  test 'query_with_id' do
    query = {:version => 1,
      'id' => {
        'from' => 1, 'to' => 5
      }
    }
    result = model.list_training_data({:query => query})
    expect_equal(5, result['total'])
  end

  test 'query_with_id_and_annotation', :params => [[0, [1, 3]], [0, [4, 6]], [1, [7, 9]]] do
    query = {
      'annotation' => {'all' => [{'pattern' => 'D'}]},
      'id' => {
        'from' => param[1].first, 'to' => param[1].last
      }
    }
    result = model.list_training_data({:query => query})
    expect_equal(param[0], result['total'])
  end
end
