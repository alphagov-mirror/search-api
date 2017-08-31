require 'integration_test_helper'

class SitemapGeneratorTest < IntegrationTest
  SAMPLE_DATA = [
    {
      "title" => "Cheese in my face",
      "description" => "Hummus weevils",
      "format" => "answer",
      "link" => "/an-example-answer",
      "indexable_content" => "I like my badger: he is tasty and delicious",
      "public_timestamp" => "2017-07-01T12:41:34+00:00"
    },
    {
      "title" => "Cheese on Ruby's face",
      "description" => "Ruby weevils",
      "format" => "answer",
      "link" => "/an-example-answer-rubylol",
      "indexable_content" => "I like my rubby badger: he is tasty and delicious"
    },
    {
      "title" => "Cheese on Python's face",
      "description" => "Python weevils",
      "format" => "answer",
      "link" => "/an-example-answer-pythonwin",
      "indexable_content" => "I like my badger: he is pythonic and delicious"
    },
    {
      "title" => "Cheese in my ears",
      "description" => "Wordpress weevils",
      "format" => "answer",
      "link" => "/an-example-answer-stuff",
      "indexable_content" => "I like my wordpress: says Joshua who is win"
    },
    {
      "title" => "Useful government information",
      "description" => "Government, government, government. Developers.",
      "format" => "answer",
      "link" => "/another-example-answer",
      "indexable_content" => "Tax, benefits, roads and stuff"
    },
    {
      "title" => "External government information",
      "description" => "Government, government, government. Developers.",
      "format" => "recommended-link",
      "link" => "http://www.example.com/external-example-answer",
      "indexable_content" => "Tax, benefits, roads and stuff"
    },
    {
      "title" => "Some content from Inside Gov",
      "description" => "We list some inside gov results in the mainstream index.",
      "format" => "inside-government-link",
      "link" => "https://www.gov.uk/government/some-content",
    }
  ].freeze

  def setup
    super
    add_sample_documents
  end

  def test_should_generate_multiple_sitemaps
    SitemapGenerator.stubs(:sitemap_limit).returns(2)
    generator = SitemapGenerator.new(search_server.content_indices)

    sitemap_xml = generator.sitemaps

    assert_equal 3, sitemap_xml.length
  end

  def test_should_include_homepage
    generator = SitemapGenerator.new(search_server.content_indices)
    sitemap_xml = generator.sitemaps

    pages = Nokogiri::XML(sitemap_xml[0])
      .css("url")
      .select { |item| item.css("loc").text == "http://www.dev.gov.uk/" }

    assert_equal 1, pages.count
    assert_equal "0.5", pages[0].css("priority").text
  end

  def test_should_not_include_recommended_links
    generator = SitemapGenerator.new(search_server.content_indices)
    sitemap_xml = generator.sitemaps

    assert_equal 1, sitemap_xml.length

    refute_includes sitemap_xml[0], "/external-example-answer"
  end

  def test_should_not_include_inside_government_links
    generator = SitemapGenerator.new(search_server.content_indices)

    sitemap_xml = generator.sitemaps

    assert_equal 1, sitemap_xml.length
    refute_includes sitemap_xml[0], "/government/some-content"
  end

  def test_links_should_include_timestamps
    generator = SitemapGenerator.new(search_server.content_indices)

    sitemap_xml = generator.sitemaps

    pages = Nokogiri::XML(sitemap_xml[0])
      .css("url")
      .select { |item| item.css("loc").text == "http://www.dev.gov.uk/an-example-answer" }

    assert_equal 1, pages.count
    assert_equal "2017-07-01T12:41:34+00:00", pages[0].css("lastmod").text
  end

  def test_links_should_include_priorities
    generator = SitemapGenerator.new(search_server.content_indices)

    sitemap_xml = generator.sitemaps

    priorities = Nokogiri::XML(sitemap_xml[0])
      .css("url > priority")

    assert_equal 6, priorities.count
  end

private

  def add_sample_documents
    SAMPLE_DATA.each do |sample_document|
      insert_document("mainstream_test", sample_document)
    end
    commit_index
  end
end