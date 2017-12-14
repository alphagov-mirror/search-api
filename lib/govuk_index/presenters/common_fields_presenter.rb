module GovukIndex
  class CommonFieldsPresenter
    CUSTOM_FORMAT_MAP = {
      "esi_fund" => "european_structural_investment_fund",
      "service_manual_homepage" => "service_manual_guide",
      "service_manual_service_standard" => "service_manual_guide",
      "topic" => "specialist_sector",
    }.freeze
    extend MethodBuilder

    delegate_to_payload :content_id
    delegate_to_payload :content_purpose_document_supertype
    delegate_to_payload :content_store_document_type, hash_key: "document_type"
    delegate_to_payload :email_document_supertype
    delegate_to_payload :government_document_supertype
    delegate_to_payload :link, hash_key: "base_path"
    delegate_to_payload :navigation_document_supertype
    delegate_to_payload :public_timestamp, hash_key: "public_updated_at"
    delegate_to_payload :publishing_app
    delegate_to_payload :rendering_app
    delegate_to_payload :search_user_need_document_supertype
    delegate_to_payload :user_journey_document_supertype

    def initialize(payload)
      @payload = payload
    end

    def description
      if format == "policy"
        summary = [] << payload["details"]["summary"]
        sanitiser = GovukIndex::IndexableContentSanitiser.new
        sanitiser.clean(summary)
      else
        payload["description"]
      end
    end

    def title
      [section_id, payload["title"]].compact.join(" - ")
    end

    def indexable_description
      format == "service_manual_topic" ? description.prepend("#{title} ") : description
    end

    def is_withdrawn
      !payload["withdrawn_notice"].nil?
    end

    def popularity
      lookup = Indexer::PopularityLookup.new("govuk_index", SearchConfig.instance)
      lookup.lookup_popularities([payload["base_path"]])[payload["base_path"]]
    end

    def format
      # TODO: remove the special case for smart answers once it is fully migrated to
      #   govuk as it's fallback `transaction` has the same implementation.
      return 'smart-answer' if payload['publishing_app'] == 'smartanswers'
      document_type = payload['document_type']
      CUSTOM_FORMAT_MAP[document_type] || document_type
    end

    def section_id
      @_section_id ||= payload.dig("details", "section_id") if format == "hmrc_manual_section"
    end

  private

    attr_reader :payload
  end
end