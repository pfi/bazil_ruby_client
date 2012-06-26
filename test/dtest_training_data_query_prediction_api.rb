require 'rubygems'
require 'json'

require 'test_helper'
require 'bazil'

SharedContext 'training_data_prediction_query_test_util' do
  def prepare_training_data
    training_data_set = []
    annotations = ['C#', 'C++', 'D']
    # add training data
    # string value data
    ['redbull', 'rockstar', 'coke'].each_with_index { |value, i|
      training_data = {'label' => annotations[i], 'data' => {'feature1' => value}}
      training_data_set << training_data.merge(model.train(annotations[i], {'feature1' => value}))
    }

    # number value data
    [500, 100_000, -1].each_with_index { |value, i|
      training_data = {'label' => annotations[i], 'data' => {'feature2' => value}}
      training_data_set << training_data.merge(model.train(annotations[i], {'feature2' => value}))
    }

    # data with label
    [['C#', ['rockstar', 10]], ['C++', ['coke', -1]], ['D', ['redbull', 1000]]].each { |label, value|
      training_data = {'label' => label, 'data' => {'feature1' => value[0], 'feature2' => value[1]}}
      training_data_set << training_data.merge(model.train(label, {'feature1' => value[0], 'feature2' => value[1]}))
    }

    # In NHERD with above training data, classifier returns following result.
    #
    # annotation = C#,  res = {"classified_labels" => {"C#" => 0, "C++" => 0, "D" => 0}, "max_label" => "C#"}
    # annotation = C++, res = {"classified_labels" => {"C#" => 0, "C++" => 0, "D" => 0}, "max_label" => "C#"}
    # annotation = D,   res = {"classified_labels" => {"C#" => 0, "C++" => 0, "D" => 0}, "max_label" => "C#"}
    # annotation = C#,  res = {"classified_labels" => {"C#" => 0.276666522026, "C++" => -0.276666522026, "D" => 0.776545166969}, "max_label" => "D"}
    # annotation = C++, res = {"classified_labels" => {"C#" => 55.3333015442, "C++" => -55.3333015442, "D" => 155.309036255}, "max_label" => "D"}
    # annotation = D,   res = {"classified_labels" => {"C#" => -0.000553333025891, "C++" => 0.000553333025891, "D" => -0.00155309028924}, "max_label" => "C++"}
    # annotation = C#,  res = {"classified_labels" => {"C#" => 0.0055333301425, "C++" => -0.0055333301425, "D" => 0.0155309028924}, "max_label" => "D"}
    # annotation = C++, res = {"classified_labels" => {"C#" => -0.000553333025891, "C++" => 0.000553333025891, "D" => -0.00155309028924}, "max_label" => "C++"}
    # annotation = D,   res = {"classified_labels" => {"C#" => 0.553333044052, "C++" => -0.553333044052, "D" => 1.55309033394}, "max_label" => "D"}"}
    #
    # Confusion matrix is below
    #
    # |     | C# | C++ | D |
    # | C#  | 1  | 1   | 1 |
    # | C++ | 0  | 1   | 1 |
    # | D   | 2  | 1   | 1 |
    #
    # Following test assumes this result

    confusion_matrix = {}
    annotations.each { |label|
      confusion_matrix[label] = {}
      annotations.each { |l|
        confusion_matrix[label][l] = 0
      }
    }
    training_data_set.each { |td|
      max_label, = model.query(td['data'], model_config_id)
      confusion_matrix[td['label']][max_label] += 1
    }

    set :confusion_matrix, confusion_matrix
    set :training_data_set, training_data_set
    set :training_data_size, get_training_data_size
  end
end

TestCase 'Bazil-server training-data-query multi-class only prediction' do
  include_context 'bazil_case_utils'
  include_context 'bazil_model_utils'
  include_context 'training_data_prediction_query_test_util'

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

  test 'query_without_config_id' do
    assert_error(Bazil::APIError) {
      query = {'version' => 1,
        'prediction' => {
          'query' => {'all' => []}
        },
      }
      model.list_training_data({:query => query})
    }
  end

  test 'query_without_query' do
    assert_error(Bazil::APIError) {
      query = {'version' => 1,
        'prediction' => {'config_id' => model_config_id}
      }
      result = model.list_training_data({:query => query})
    }
  end

  test 'query_with_unknown_config_id'  do
    assert_error(Bazil::APIError) {
      query = {'version' => 1,
        'prediction' => {
          'query' => {'all' => []},
          'config_id' => 'unknown'
        }
      }
      result = model.list_training_data({:query => query})
    }
  end

  test 'query_with_invalid_value', :params => ['saitama', true, nil, 199, {}] do
    assert_error(Bazil::APIError) {
      query = {'version' => 1,
        'prediction' => {
          'query' => {'all' => param},
          'config_id' => model_config_id
        }
      }
      result = model.list_training_data({:query => query})
    }
  end

  test 'query_for_each_cell_of_confusion_matrix', :params => ['all', 'any'] do
    # I want to use parameterized test with confusion_matrix variable...
    confusion_matrix.map { |annotation, classified|
      classified.map { |prediction, count| [count, {'annotation' => annotation, 'prediction' => prediction}] }
    }.flatten(1).each { |test_set|
      query = {'version' => 1,
        'prediction' => {
          'query' => {param => [{'label' => test_set[1]}]},
          'config_id' => model_config_id
        }
      }

      result = model.list_training_data({:query => query})
      expect_equal(test_set[0], result['training_data'].size)
    }
  end

  test 'query_with_all_patterns' do
    confusion_matrix.each_pair { |annotation, classified|
      query = {'version' => 1,
        'prediction' => {
          'query' => {'all' => classified.map { |prediction, count|
              {'label' => {'annotation' => annotation, 'prediction' => prediction}}
            }
          },
          'config_id' => model_config_id
        }
      }

      result = model.list_training_data({:query => query})
      expect_equal(0, result['training_data'].size)
    }
  end

  test 'get_all_with_any_patterns' do
    any_patterns = confusion_matrix.map { |annotation, classified|
      classified.map { |prediction, count| {'label' => {'annotation' => annotation, 'prediction' => prediction}} }
    }.flatten(1)
    query = {'version' => 1,
      'prediction' => {
        'query' => {'any' => any_patterns},
        'config_id' => model_config_id
      }
    }

    result = model.list_training_data({:query => query})
    expect_equal(training_data_size, result['training_data'].size)
  end

  test 'query_with_any_patterns' do
    confusion_matrix.each_pair { |annotation, classified|
      num = 0
      query = {'version' => 1,
        'prediction' => {
          'query' => {'any' => classified.map { |prediction, count|
              num += count
              {'label' => {'annotation' => annotation, 'prediction' => prediction}}
            }
          },
          'config_id' => model_config_id
        }
      }

      result = model.list_training_data({:query => query})
      expect_equal(num, result['training_data'].size)
    }
  end

  test 'any_query_with_page_size' do
    query = {'version' => 1,
      'prediction' => {
        'query' => {
          'any' => [{'label' => {'annotation' => 'C#', 'prediction' => 'D'}}]
        },
        'config_id' => model_config_id
      }
    }

    result = model.list_training_data({:query => query, :page_size => 1})
    expect_equal(1, result['training_data'].size)
    expect_equal(2, result['total'])
  end

  test 'query_with_any_and_not_patterns' do
    confusion_matrix.each_pair { |annotation, classified|
      num = 0
      any_patterns = classified.map { |prediction, count|
        num += count
        {'label' => {'annotation' => annotation, 'prediction' => prediction}}
      }
      classified.each_pair { |prediction, count|
        query = {'version' => 1,
          'prediction' => {
            'query' => {
              'any' => any_patterns,
              'not' => [{'label' => {'annotation' => annotation, 'prediction' => prediction}}]
            },
            'config_id' => model_config_id
          }
        }

        result = model.list_training_data({:query => query})
        expect_equal(num - count, result['training_data'].size)
      }
    }
  end

  test 'query_with_only_not_patterns' do
    confusion_matrix.each_pair { |annotation, classified|
      num = 0
      any_patterns = classified.map { |prediction, count|
        num += count
        {'label' => {'annotation' => annotation, 'prediction' => prediction}}
      }
      classified.each_pair { |prediction, count|
        query = {'version' => 1,
          'prediction' => {
            'query' => {
              'not' => [{'label' => {'annotation' => annotation, 'prediction' => prediction}}]
            },
            'config_id' => model_config_id
          }
        }

        result = model.list_training_data({:query => query})
        expect_equal(0, result['training_data'].size) # not must be used with all or any
      }
    }
  end
end

TestCase 'Bazil-server training-data-query multi-class prediction with label condition' do
  include_context 'bazil_case_utils'
  include_context 'bazil_model_utils'
  include_context 'training_data_prediction_query_test_util'

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

  test 'any_patterns_with_each_annotation', :params => ['C#', 'C++', 'D'] do
    any_patterns = confusion_matrix.map { |annotation, classified|
      classified.map { |prediction, _| {'label' => {'annotation' => annotation, 'prediction' => prediction}} }
    }.flatten(1)
    query = {'version' => 1,
      'label' => {
        'all' => [{'pattern' => Regexp.escape(param)}]
      },
      'prediction' => {
        'query' => {'any' => any_patterns},
        'config_id' => model_config_id
      }
    }

    annotated_training_data_num = confusion_matrix[param].inject(0) { |sum, classified| sum + classified.last }
    result = model.list_training_data({:query => query})
    expect_equal(annotated_training_data_num, result['training_data'].size)
  end
end

TestCase 'Bazil-server training-data-query multi-class prediction with field condition' do
  include_context 'bazil_case_utils'
  include_context 'bazil_model_utils'
  include_context 'training_data_prediction_query_test_util'

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

  test 'all_patterns_with_each_feature1', :params => ['redbull', 'rockstar', 'coke'] do
    any_patterns = confusion_matrix.map { |annotation, classified|
      classified.map { |prediction, _| {'label' => {'annotation' => annotation, 'prediction' => prediction}} }
    }.flatten(1)
    query = {'version' => 1,
      'field' => {
        'feature1' => {'all' => [{'pattern' => param}]},
      },
      'prediction' => {
        'query' => {'any' => any_patterns},
        'config_id' => model_config_id
      }
    }

    training_data_num = training_data_set.select { |td| td['data']['feature1'] == param }.size
    result = model.list_training_data({:query => query})
    expect_equal(training_data_num, result['training_data'].size)
  end

  test 'any_patterns_with_each_feature2' do
    any_patterns = confusion_matrix.map { |annotation, classified|
      classified.map { |prediction, _| {'label' => {'annotation' => annotation, 'prediction' => prediction}} }
    }.flatten(1)
    query = {'version' => 1,
      'field' => {
        'feature2' => {'any' => [{'range' => {'from' => -1000, 'to' => 1000_000}}]}
      },
      'prediction' => {
        'query' => {'any' => any_patterns},
        'config_id' => model_config_id
      }
    }

    training_data_num = training_data_set.select { |td| td['data'].has_key?('feature2') }.size
    result = model.list_training_data({:query => query})
    expect_equal(training_data_num, result['training_data'].size)
  end
end
