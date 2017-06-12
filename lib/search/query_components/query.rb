require_relative "core_query"
require_relative "text_query"

module QueryComponents
  class Query < BaseComponent
    def payload
      if search_params.similar_to.nil?
        QueryComponents::BestBets.new(search_params).wrap(base_query)
      else
        more_like_this_query_hash
      end
    end

  private

    def base_query
      return { match_all: {} } if search_term.nil?

      if search_params.enable_new_weighting?
        core_query = QueryComponents::TextQuery.new(search_params).payload
      else
        core_query = QueryComponents::CoreQuery.new(search_params).payload
      end

      boosted_query = QueryComponents::Booster.new(search_params).wrap(core_query)
      QueryComponents::Popularity.new(search_params).wrap(boosted_query)
    end

    def more_like_this_query_hash
      content_indices = Rummager.search_config.content_index_names

      docs = content_indices.reduce([]) do |documents, index_name|
        documents << {
          _type: 'edition',
          _id: search_params.similar_to,
          _index: index_name
        }
      end

      {
        more_like_this: { docs: docs }
      }
    end
  end
end
