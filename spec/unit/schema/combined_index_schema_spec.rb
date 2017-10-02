require 'spec_helper'

RSpec.describe CombinedIndexSchema do
  before do
    @base_uri = URI.parse("http://example.com:9200")
    @search_config = SearchConfig.new
    @index_names = @search_config.content_index_names
    @combined_schema = described_class.new(@index_names, @search_config.schema_config)
  end

  it "basic_field_definitions" do
    # The title and public_timestamp fields are defined in the
    # base_elasticsearch_type, so are available in all documents holding content.
    expect(@combined_schema.field_definitions["title"].type.name).to eq("searchable_sortable_text")
    expect(@combined_schema.field_definitions["description"].type.name).to eq("searchable_text")
    expect(@combined_schema.field_definitions["public_timestamp"].type.name).to eq("date")
  end

  it "merged_field_definitions" do
    # The location field is defined in both the
    # international_development_fund document type, and in the
    # european_structural_investment_fund document type, with different
    # expanded_search_result_fields.  Check that expansion values from both lists are present.
    locations = @combined_schema.field_definitions["location"].expanded_search_result_fields
    expect(locations).to include({ "label" => "Afghanistan", "value" => "afghanistan" })
    expect(locations).to include({ "label" => "North East", "value" => "north-east" })
  end

  it "allowed_filter_fields" do
    expect(@combined_schema.allowed_filter_fields).not_to include "title"
    expect(@combined_schema.allowed_filter_fields).to include "organisations"
  end
end
