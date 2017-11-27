module GovukIndex
  class IndexableContentPresenter
    DEFAULTS = %w(body parts).freeze
    BY_FORMAT = {
      'contact'     => %w(title description),
      'licence'     => %w(licence_short_description licence_overview),
      'transaction' => %w(introductory_paragraph more_information),
    }.freeze
    INDEX_DESCRIPTION_FIELD = %w(manual service_manual_topic).freeze

    def initialize(format:, details:, sanitiser:)
      @format    = format
      @details   = details
      @sanitiser = sanitiser
    end

    def indexable_content
      return nil if details.nil? || INDEX_DESCRIPTION_FIELD.include?(format)
      sanitiser.clean(indexable)
    end

  private

    attr_reader :details, :format, :sanitiser

    def indexable
      indexable_content_parts + hidden_content + contact_groups_titles
    end

    def hidden_content
      Array(details.dig('metadata', 'hidden_indexable_content') || [])
    end

    def indexable_content_parts
      indexable_content_keys.flat_map do |field|
        indexable_values = details[field] || []
        field == 'parts' ? parts(indexable_values) : [indexable_values]
      end
    end

    def indexable_content_keys
      DEFAULTS + BY_FORMAT.fetch(format, [])
    end

    def parts(items)
      items.flat_map do |item|
        [item['title'], item['body']]
      end
    end

    def contact_groups_titles
      details.fetch('contact_groups', []).map { |contact| contact['title'] }
    end
  end
end
