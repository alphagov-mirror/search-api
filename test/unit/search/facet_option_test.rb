require "test_helper"
require "search/facet_option"

class FacetOptionTest < MiniTest::Unit::TestCase
  def test_convert_to_hash
    assert_equal(
      { value: { "title" => "Hello" }, documents: 1 },
      Search::FacetOption.new({ "title" => "Hello" }, 1, true, []).as_hash,
    )
  end

  def test_id_is_slug
    assert_equal(
      "a_slug",
      Search::FacetOption.new({ "title" => "Hello", "slug" => "a_slug" }, 1, true, []).id,
    )
  end

  def test_compare_by_filtered_first
    orderings = [[:filtered, 1]]
    assert(
      Search::FacetOption.new({}, 0, true, orderings) <
      Search::FacetOption.new({}, 0, false, orderings)
    )
  end

  def test_compare_by_filtered_last
    orderings = [[:filtered, -1]]
    assert(
      Search::FacetOption.new({}, 0, false, orderings) <
      Search::FacetOption.new({}, 0, true, orderings)
    )
  end

  def test_compare_by_count_ascending
    orderings = [[:count, 1]]
    assert(
      Search::FacetOption.new({}, 5, false, orderings) <
      Search::FacetOption.new({}, 6, false, orderings)
    )
  end

  def test_compare_by_count_descending
    orderings = [[:count, -1]]
    assert(
      Search::FacetOption.new({}, 6, false, orderings) <
      Search::FacetOption.new({}, 5, false, orderings)
    )
  end


  def test_compare_by_slug_ascending
    orderings = [[:"value.slug", 1]]
    assert(
      Search::FacetOption.new({ "slug" => "a" }, 0, false, orderings) <
      Search::FacetOption.new({ "slug" => "b" }, 0, false, orderings)
    )
  end

  def test_compare_by_slug_descending
    orderings = [[:"value.slug", -1]]
    assert(
      Search::FacetOption.new({ "slug" => "b" }, 0, false, orderings) <
      Search::FacetOption.new({ "slug" => "a" }, 0, false, orderings)
    )
  end

  def test_compare_by_title_ascending
    orderings = [[:"value.title", 1]]
    assert(
      Search::FacetOption.new({ "title" => "a" }, 0, false, orderings) <
      Search::FacetOption.new({ "title" => "b" }, 0, false, orderings)
    )
  end

  def test_compare_by_title_descending
    orderings = [[:"value.title", -1]]
    assert(
      Search::FacetOption.new({ "title" => "b" }, 0, false, orderings) <
      Search::FacetOption.new({ "title" => "a" }, 0, false, orderings)
    )
  end

  def test_compare_by_title_ignores_case
    orderings = [[:"value.title", 1]]
    assert(
      Search::FacetOption.new({ "title" => "a" }, 0, false, orderings) <
      Search::FacetOption.new({ "title" => "Z" }, 0, false, orderings)
    )
  end

  def test_compare_by_link_ascending
    orderings = [[:"value.link", 1]]
    assert(
      Search::FacetOption.new({ "link" => "a" }, 0, false, orderings) <
      Search::FacetOption.new({ "link" => "b" }, 0, false, orderings)
    )
  end

  def test_compare_by_link_descending
    orderings = [[:"value.link", -1]]
    assert(
      Search::FacetOption.new({ "link" => "b" }, 0, false, orderings) <
      Search::FacetOption.new({ "link" => "a" }, 0, false, orderings)
    )
  end

  def test_compare_by_value
    orderings = [[:value, 1]]
    assert(
      Search::FacetOption.new("a", 0, false, orderings) <
      Search::FacetOption.new("b", 0, false, orderings)
    )
  end

  def test_compare_by_value_with_title
    orderings = [[:value, 1]]
    assert(
      Search::FacetOption.new({ "title" => "a" }, 0, false, orderings) <
      Search::FacetOption.new({ "title" => "b" }, 0, false, orderings)
    )
  end

  def test_fall_back_to_slug_ordering
    orderings = [[:count, 1]]
    assert(
      Search::FacetOption.new({ "slug" => "a" }, 5, false, orderings) <
      Search::FacetOption.new({ "slug" => "b" }, 5, false, orderings)
    )
  end
end
