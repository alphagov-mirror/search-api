require "test_helper"
require "search/suggestion_blacklist"

class Search::SuggestionBlacklistTest < ShouldaUnitTestCase
  def blacklist
    Search::SuggestionBlacklist.new(
      { organisations: stubbed_organisation_registry }
    )
  end

  def stubbed_organisation_registry
    mod_organisation = {
      "link" => "/government/organisations/ministry-of-defence",
      "title" => "Ministry of Defence",
      "acronym" => "MoD",
      "organisation_type" => "Ministerial department"
    }

    stub('organisation_registry', all: [mod_organisation])
  end

  context "#should_correct?" do
    should "correct normal strings" do
      assert blacklist.should_correct?("some test")
    end

    should "not correct strings with numbers" do
      refute blacklist.should_correct?("86asrdv")
    end

    should "correct words in ignore.txt" do
      refute blacklist.should_correct?("bodrum")
    end

    should "correct words in the organization" do
      refute blacklist.should_correct?("mod")
    end
  end
end
