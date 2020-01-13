module LearnToRank::DataPipeline
  class EmbedFeatures
    # EmbedFeatures takes a set of relevancy judgements and add features to them.
    # INPUT: enumerator of { query: "a1", "id": "123456", score: 1 }
    # OUTPUT: lazy enumerator of { query: "a1", "id": "123456", score: 1, view_count: 2, description_score: 2, title_score: 4 ... }
    def initialize(judgements)
      @judgements = judgements
    end

    def augmented_judgements
      cached_queries = {}
      augmented = judgements.lazy.map do |judgement|
        next nil unless judgement

        feats = features(judgement, cached_queries)
        next nil unless feats

        cached_queries = {} if cached_queries.keys.count > 25

        judgement.merge(feats)
      end
      augmented.reject(&:nil?)
    end

  private

    attr_reader :judgements

    def features(judgement, cached_queries)
      doc = fetch_document(judgement, cached_queries)
      return unless doc

      feats = LearnToRank::Features.new(
        explain: doc.fetch(:_explanation, {}),
        popularity: doc["popularity"],
        es_score: doc[:es_score],
        title: doc["title"],
        description: doc["description"],
        link: doc["link"],
        public_timestamp: doc["public_timestamp"],
        format: doc["format"],
        organisation_content_ids: doc["organisation_content_ids"],
        query: judgement[:query],
        indexable_content: doc["indexable_content"],
        updated_at: doc["updated_at"],
      ).as_hash

      { features: feats }
    end

    def fetch_document(judgement, cached_queries)
      # TODO: Could we use MTerm Vectors API for this?
      begin
        retries ||= 0
        query = {
          "q" => [judgement[:query]],
          "debug" => %w(explain),
          "fields" => %w(popularity content_id title format description link public_timestamp organisation_content_ids updated_at indexable_content),
          "count" => %w[20],
        }
        cached_queries[judgement[:query]] ||= do_fetch(query)
        results = cached_queries[judgement[:query]]

        results.find { |doc| doc["link"] == judgement[:link] }
      rescue StandardError => e
        puts e
        sleep 5
        retry if (retries += 1) < 3
        nil
      end
    end

    def do_fetch(query)
      sleep 0.05
      SearchConfig.run_search(query)[:results]
    end

    def logger
      Logging.logger.root
    end
  end
end
