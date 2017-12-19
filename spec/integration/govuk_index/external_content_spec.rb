require 'spec_helper'

RSpec.describe "external content publishing" do
  before do
    bunny_mock = BunnyMock.new
    @channel = bunny_mock.start.channel

    consumer = GovukMessageQueueConsumer::Consumer.new(
      queue_name: "external_content.test",
      processor: GovukIndex::PublishingEventProcessor.new,
      rabbitmq_connection: bunny_mock
    )

    @queue = @channel.queue("external_content.test")
    consumer.run
  end

  it "indexes a page of external content" do
    random_example = generate_random_example(
      schema: "external_content",
      payload: {
        document_type: "external_content",
      },
      details: {
        hidden_search_terms: ["some, search, keywords"]
      },
    )

    allow(GovukIndex::MigratedFormats).to receive(:indexable_formats).and_return("recommended-link" => :all)

    @queue.publish(random_example.to_json, content_type: "application/json")

    expected_document = {
       "link" => random_example["details"]["url"],
       "format" => "recommended-link",
       "title" => random_example["title"],
       "description" => random_example["description"],
       "indexable_content" => "some, search, keywords",
     }

    expect_document_is_in_rummager(expected_document, index: "govuk_test", type: "edition")
  end
end
