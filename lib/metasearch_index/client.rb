module MetasearchIndex
  class Client < Index::Client
    class << self
      delegate :analyze, to: :instance
    end

    def analyze(params)
      client.indices.analyze(params.merge(index: index_name))
    end

  private

    def index_name
      @_index ||= search_config.metasearch_index_name
    end
  end
end
