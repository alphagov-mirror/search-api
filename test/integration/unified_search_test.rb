require "integration_test_helper"

class UnifiedSearchTest < IntegrationTest
  def setup
    # `@@registries` are set in Rummager and is *not* reset between tests. To
    # prevent caching issues we manually clear them here to make a "new" app.
    Rummager.class_variable_set(:'@@registries', nil)

    stub_elasticsearch_settings
    create_meta_indexes
  end

  def teardown
    clean_test_indexes
  end

  def test_returns_success
    reset_content_indexes

    get "/unified_search?q=important"

    assert last_response.ok?
  end

  def test_spell_checking_with_typo
    reset_content_indexes

    commit_document("mainstream_test",
      title: "I am the result",
      description: "This is a test search result",
      link: "/some-nice-link"
    )

    get "/unified_search?q=serch&suggest=spelling"

    assert_equal ['search'], parsed_response['suggested_queries']
  end

  def test_spell_checking_without_typo
    reset_content_indexes_with_content(section_count: 1)

    get "/unified_search?q=milliband"

    assert_equal [], parsed_response['suggested_queries']
  end

  def test_returns_docs_from_all_indexes
    reset_content_indexes_with_content(section_count: 1)

    get "/unified_search?q=important"

    assert result_links.include? "/government-1"
    assert result_links.include? "/mainstream-1"
  end

  def test_sort_by_date_ascending
    reset_content_indexes_with_content(section_count: 2)

    get "/unified_search?q=important&order=public_timestamp"

    assert_equal ["/government-1", "/government-2"],
      result_links.take(2)
  end

  def test_sort_by_date_descending
    reset_content_indexes_with_content(section_count: 2)

    get "/unified_search?q=important&order=-public_timestamp"

    # The government links have dates, so appear before all the other links.
    # The other documents have no dates, so appear in an undefined order
    assert_equal ["/government-2", "/government-1"],
      result_links.take(2)
  end

  def test_sort_by_title_ascending
    reset_content_indexes_with_content(section_count: 1)

    get "/unified_search?order=title"
    lowercase_titles = result_titles.map(&:downcase)

    assert_equal lowercase_titles, lowercase_titles.sort
  end

  def test_filter_by_field
    reset_content_indexes_with_content(section_count: 1)

    get "/unified_search?filter_mainstream_browse_pages=1"

    assert_equal ["/government-1", "/mainstream-1"],
      result_links.sort
  end

  def test_reject_by_field
    reset_content_indexes_with_content(section_count: 2)

    get "/unified_search?reject_mainstream_browse_pages=1"

    assert_equal ["/government-2", "/mainstream-2"],
      result_links.sort
  end

  def test_can_filter_for_missing_field
    reset_content_indexes_with_content(section_count: 1)

    get "/unified_search?filter_specialist_sectors=_MISSING"

    assert_equal ["/government-1", "/mainstream-1"],
      result_links.sort
  end

  def test_can_filter_for_missing_or_specific_value_in_field
    reset_content_indexes_with_content(section_count: 1)

    get "/unified_search?filter_specialist_sectors[]=_MISSING&filter_specialist_sectors[]=farming"

    assert_equal ["/government-1", "/mainstream-1"],
      result_links.sort
  end

  def test_can_filter_and_reject
    reset_content_indexes_with_content(section_count: 2)

    get "/unified_search?reject_mainstream_browse_pages=1&filter_specialist_sectors[]=farming"

    assert_equal [
      "/government-2",
      "/mainstream-2",
    ], result_links.sort
  end

  def test_only_contains_fields_which_are_present
    reset_content_indexes_with_content(section_count: 2)

    get "/unified_search?q=important&order=public_timestamp"

    results = parsed_response["results"]
    refute_includes results[0].keys, "specialist_sectors"
    assert_equal [{"slug"=>"farming"}], results[1]["specialist_sectors"]
  end

  def test_facet_counting
    reset_content_indexes_with_content(section_count: 2)

    get "/unified_search?q=important&facet_mainstream_browse_pages=2"

    assert_equal 4, parsed_response["total"]

    facets = parsed_response["facets"]

    assert_equal({
      "mainstream_browse_pages" => {
        "options" => [
          {"value"=>{"slug"=>"1"}, "documents"=>2},
          {"value"=>{"slug"=>"2"}, "documents"=>2},
        ],
        "documents_with_no_value" => 0,
        "total_options" => 2,
        "missing_options" => 0,
        "scope" => "exclude_field_filter",
      }
    }, facets)
  end

  # TODO: The `mainstream_browse_pages` fields are populated with a number, 1
  # or 2. This should be made more explicit.
  def test_facet_counting_with_filter_on_field_and_exclude_field_filter_scope
    reset_content_indexes_with_content(section_count: 2)

    get "/unified_search?q=important&facet_mainstream_browse_pages=2"

    assert_equal 4, parsed_response["total"]
    facets_without_filter = parsed_response["facets"]

    get "/unified_search?q=important&facet_mainstream_browse_pages=2&filter_mainstream_browse_pages=1"
    assert_equal 2, parsed_response["total"]

    facets_with_filter = parsed_response["facets"]

    assert_equal(facets_with_filter, facets_without_filter)
    assert_equal(2, facets_without_filter["mainstream_browse_pages"]["options"].size)
  end

  def test_facet_counting_missing_options
    reset_content_indexes_with_content(section_count: 2)

    get "/unified_search?q=important&facet_mainstream_browse_pages=1"

    assert_equal 4, parsed_response["total"]
    facets = parsed_response["facets"]
    assert_equal({
      "mainstream_browse_pages" => {
        "options" => [
          {"value"=>{"slug"=>"1"}, "documents"=>2},
        ],
        "documents_with_no_value" => 0,
        "total_options" => 2,
        "missing_options" => 1,
        "scope" => "exclude_field_filter",
      }
    }, facets)
  end

  def test_facet_counting_with_filter_on_field_and_all_filters_scope
    reset_content_indexes_with_content(section_count: 2)

    get "/unified_search?q=important&facet_mainstream_browse_pages=2,scope:all_filters&filter_mainstream_browse_pages=1"

    assert_equal 2, parsed_response["total"]
    facets = parsed_response["facets"]

    assert_equal({
      "mainstream_browse_pages" => {
        "options" => [
          {"value"=>{"slug"=>"1"}, "documents"=>2},
        ],
        "documents_with_no_value" => 0,
        "total_options" => 1,
        "missing_options" => 0,
        "scope" => "all_filters",
      }
    }, facets)
  end

  def test_facet_examples
    reset_content_indexes_with_content(section_count: 2)

    get "/unified_search?q=important&facet_mainstream_browse_pages=1,examples:5,example_scope:global,example_fields:link:title:mainstream_browse_pages"

    assert_equal(
      ["/government-1", "/mainstream-1"],
      parsed_response["facets"]["mainstream_browse_pages"]["options"].first["value"]["example_info"]["examples"].map { |h| h["link"] }.sort
    )
  end

  def test_validates_integer_params
    reset_content_indexes

    get "/unified_search?start=a"

    assert_equal last_response.status, 422
    assert_equal parsed_response, {"error" => "Invalid value \"a\" for parameter \"start\" (expected positive integer)"}
  end

  def test_allows_integer_params_leading_zeros
    reset_content_indexes

    get "/unified_search?start=09"

    assert last_response.ok?
  end

  def test_validates_unknown_params
    reset_content_indexes

    get "/unified_search?foo&bar=1"

    assert_equal last_response.status, 422
    assert_equal parsed_response, {"error" => "Unexpected parameters: foo, bar"}
  end

  def test_debug_explain_returns_explanations
    reset_content_indexes_with_content(section_count: 1)

    get "/unified_search?debug=explain"

    first_hit_explain = parsed_response["results"].first["_explanation"]
    refute_nil first_hit_explain
    assert first_hit_explain.keys.include?("value")
    assert first_hit_explain.keys.include?("description")
    assert first_hit_explain.keys.include?("details")
  end

  def test_can_scope_by_document_type
    reset_content_indexes
    commit_document("mainstream_test", cma_case_attributes)

    get "/unified_search?filter_document_type=cma_case"

    assert last_response.ok?
    assert_equal 1, parsed_response.fetch("total")
    assert_equal(
      hash_including(
        "document_type" => cma_case_attributes.fetch("_type"),
        "title" => cma_case_attributes.fetch("title"),
        "link" => cma_case_attributes.fetch("link"),
      ),
      parsed_response.fetch("results").fetch(0),
    )
  end

  def test_can_filter_between_dates
    reset_content_indexes
    commit_document("mainstream_test", cma_case_attributes)

    get "/unified_search?filter_document_type=cma_case&filter_opened_date=from:2014-03-31,to:2014-04-02"

    assert last_response.ok?
    assert_equal 1, parsed_response.fetch("total")
    assert_equal(
      hash_including(
        "title" => cma_case_attributes.fetch("title"),
        "link" => cma_case_attributes.fetch("link"),
      ),
      parsed_response.fetch("results").fetch(0),
    )
  end

  def test_can_filter_between_dates_with_reversed_parameter_order
    reset_content_indexes
    commit_document("mainstream_test", cma_case_attributes)

    get "/unified_search?filter_document_type=cma_case&filter_opened_date=to:2014-04-02,from:2014-03-31"

    assert last_response.ok?
    assert_equal 1, parsed_response.fetch("total")
    assert_equal(
      hash_including(
        "title" => cma_case_attributes.fetch("title"),
        "link" => cma_case_attributes.fetch("link"),
      ),
      parsed_response.fetch("results").fetch(0),
    )
  end

  def test_can_filter_from_date
    reset_content_indexes
    commit_document("mainstream_test", cma_case_attributes)

    get "/unified_search?filter_document_type=cma_case&filter_opened_date=from:2014-03-31"

    assert last_response.ok?
    assert_equal 1, parsed_response.fetch("total")
    assert_equal(
      hash_including(
        "title" => cma_case_attributes.fetch("title"),
        "link" => cma_case_attributes.fetch("link"),
      ),
      parsed_response.fetch("results").fetch(0),
    )
  end

  def test_can_filter_to_date
    reset_content_indexes
    commit_document("mainstream_test", cma_case_attributes)

    get "/unified_search?filter_document_type=cma_case&filter_opened_date=to:2014-04-02"

    assert last_response.ok?
    assert_equal 1, parsed_response.fetch("total")
    assert_equal(
      hash_including(
        "title" => cma_case_attributes.fetch("title"),
        "link" => cma_case_attributes.fetch("link"),
      ),
      parsed_response.fetch("results").fetch(0),
    )
  end

  def test_cannot_provide_date_filter_key_multiple_times
    reset_content_indexes

    get "/unified_search?filter_document_type=cma_case&filter_opened_date[]=from:2014-03-31&filter_opened_date[]=to:2014-04-02"

    assert_equal 422, last_response.status
    assert_equal(
      {"error" => %{Too many values (2) for parameter "opened_date" (must occur at most once)}},
      parsed_response,
    )
  end

  def test_cannot_provide_invalid_dates_for_date_filter
    reset_content_indexes

    get "/unified_search?filter_document_type=cma_case&filter_opened_date=from:not-a-date"

    assert_equal 422, last_response.status
    assert_equal(
      {"error" => %{Invalid value "not-a-date" for parameter "opened_date" (expected ISO8601 date}},
      parsed_response,
    )
  end

  def test_expandinging_of_organisations
    reset_content_indexes

    commit_document("mainstream_test",
      title: 'Advice on Treatment of Dragons',
      link: '/dragon-guide',
      organisations: ['/ministry-of-magic']
    )

    commit_document("government_test",
      slug: '/ministry-of-magic',
      title: 'Ministry of Magic',
      link: '/ministry-of-magic-site',
      format: 'organisation'
    )

    get "/unified_search.json?q=dragons"

    assert_equal first_result['organisations'],
      [{ "slug"=>"/ministry-of-magic",
         "link"=>"/ministry-of-magic-site",
         "title"=>"Ministry of Magic" }]
  end

  def test_id_search
    reset_content_indexes_with_content(section_count: 1)

    get "/unified_search?q=id1&debug=new_weighting"

    assert result_links.include? "/mainstream-1"
  end

  def test_withdrawn_content
    reset_content_indexes

    commit_document("mainstream_test",
      title: "I am the result",
      description: "This is a test search result",
      link: "/some-nice-link",
      is_withdrawn: true
    )

    get "/unified_search?q=test"
    assert_equal 0, parsed_response.fetch("total")
  end

  def test_withdrawn_content_with_flag
    reset_content_indexes

    commit_document("mainstream_test",
      title: "I am the result",
      description: "This is a test search result",
      link: "/some-nice-link",
      is_withdrawn: true
    )

    get "/unified_search?q=test&debug=include_withdrawn"
    assert_equal 1, parsed_response.fetch("total")
  end

  private

  def first_result
    @first_result ||= parsed_response['results'].first
  end

  def result_links
    @_result_links ||= parsed_response["results"].map do |result|
      result["link"]
    end
  end

  def result_titles
    @_result_titles ||= parsed_response["results"].map do |result|
      result["title"]
    end
  end

  def cma_case_attributes
    {
      "title" => "Somewhat Unique CMA Case",
      "link" => "/cma-cases/somewhat-unique-cma-case",
      "indexable_content" => "Mergers of cheeses and faces",
      "_type" => "cma_case",
      "specialist_sectors" => ["farming"],
      "opened_date" => "2014-04-01",
    }
  end
end
