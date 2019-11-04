module LearnToRank
  class JudgementsToSvm
    # JudgementsToSvm translates judgements to SVM format
    # IN: [{ query: "tax", rank: 2, features: { "1": 2, "2": 0.1 } }]
    # OUT: "2 qid:4 1:2 2:0.1"
    def initialize(judgements = [])
      @judgements = judgements
      @queries = get_query_ids(judgements)
    end

    def svm_format
      judgements.map { |j| judgement_to_svm(j) }
    end

  private

    attr_reader :judgements, :queries

    def judgement_to_svm(j)
      rank = "#{j[:rank]}"
      query_id = "qid:#{queries[j[:query]]}"
      feats = j[:features].map { |(key, value)| "#{key}:#{value}" }
      [rank, query_id, feats].flatten.compact.join(" ")
    end

    def get_query_ids(judgements)
      latest = 0
      judgements.each_with_object({}) do |judgement, hsh|
        next if hsh[judgement[:query]]
        hsh[judgement[:query]] = (latest += 1)
      end
    end
  end
end
