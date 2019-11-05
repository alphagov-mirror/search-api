module Search
  SpellCheckPresenter = Struct.new(:search_params, :es_response) do
    def present
      return [] unless any_suggestions?

      if search_params.use_best_suggestion?
        [
          best_suggestion(
            es_response["suggest"]["spelling_suggestions"][0]["text"],
            es_response["suggest"]["spelling_suggestions"][0]["options"],
          )
        ]
      else
        [es_response["suggest"]["spelling_suggestions"][0]["options"][0]["text"]]
      end
    end

  private

    def any_suggestions?
      es_response["suggest"] && es_response["suggest"].any?
    end

    # Get the best suggestion by ranking suggestions by string
    # distance, using the Elasticsearch score as a tiebreaker.  This
    # is necessary because Elasticsearch doesn't support the "sort"
    # option for the phrase suggester, which is what we're using.
    #
    # The Elasticsearch score is influenced by the string distance
    # function used, but not enough for us to effectively get
    # distance-first sorting.
    def best_suggestion(query, options)
      return options[0]["text"] if options.length == 1

      best_suggestion = nil
      best_distance = nil
      best_es_score = nil
      options.each do |suggestion|
        distance = string_distance(query, suggestion["text"])
        es_score = suggestion["score"]

        next unless best_suggestion.nil? || distance < best_distance || distance == best_distance && es_score > best_es_score

        best_suggestion = suggestion["text"]
        best_distance = distance
        best_es_score = es_score
      end

      best_suggestion
    end

    # Damerau-Levenshtein, translated from Lucene's java code:
    # https://github.com/apache/lucene-solr/blob/master/lucene/suggest/src/java/org/apache/lucene/search/spell/LuceneLevenshteinDistance.java
    def string_distance(target, other)
      n = target.length
      m = other.length

      return [m, n].max if m.zero? || n.zero?

      d = []
      (n + 1).times do
        row = []
        (m + 1).times do
          row << 0
        end
        d << row
      end

      n.times do |i|
        d[i][0] = i
      end

      m.times do |j|
        d[0][j] = j
      end

      (1..m).each do |j|
        t_j = other[j-1]

        (1..n).each do |i|
          cost = target[i - 1] == t_j ? 0 : 1
          d[i][j] = [d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost].min
          if i > 1 && j > 1 && target[i - 1] == other[j - 2] && target[i - 2] == other[j - 1]
            d[i][j] = [d[i][j], d[i - 2][j - 2] + cost].min
          end
        end
      end

      d[n][m]
    end
  end
end
