module HealthCheck
  SuggestionCheckResult = Struct.new(:success, :score, :possible_score, :tags)
end
