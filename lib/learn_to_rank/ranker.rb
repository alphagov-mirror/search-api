require "aws-sdk-sagemakerruntime"
require "httparty"

module LearnToRank
  class Ranker
    include Errors
    include RankerApiHelper

    # Ranker takes feature sets and requests new scores for them
    # from a pre-trained model.
    def initialize(feature_sets = [])
      @feature_sets = feature_sets
    end

    def ranks
      return nil unless feature_sets.any?

      fetch_new_scores(feature_sets)
    end

  private

    attr_reader :feature_sets

    def fetch_new_scores(examples)
      if sagemaker_endpoint
        fetch_new_scores_from_sagemaker(examples)
      else
        fetch_new_scores_from_serving(examples)
      end
    end

    def fetch_new_scores_from_sagemaker(examples)
      begin
        response = Aws::SageMakerRuntime::Client.new.invoke_endpoint(
          endpoint_name: sagemaker_endpoint,
          body: {
            "signature_name": "regression",
            "examples": examples,
          }.to_json,
          content_type: "application/json",
          custom_attributes: "tfs-method=regress",
        )
      rescue Aws::SageMakerRuntime::Errors::ServiceError => e
        logger.debug "SageMaker: #{e.message}"
        report_error(e)
        return nil
      end

      if response.nil? || response.body.empty?
        logger.debug "SageMaker: No response from ranker!"
        report_error(InvalidSageMakerResponse.new, extra: { response: response })
        return nil
      else
        logger.debug "SageMaker: #{response.body}"
      end

      JSON.parse(response.body).fetch("results")
    end

    def fetch_new_scores_from_serving(examples)
      url = "#{tensorflow_container_url}:regress"
      options = {
        method: "POST",
        body: {
          "signature_name": "regression",
          "examples": examples,
        }.to_json,
        headers: { "Content-Type" => "application/json" },
      }

      begin
        response = HTTParty.post(url, options)
      rescue StandardError => e
        logger.debug "TF Serving: status_code: 500, message: #{e.message}"
        report_error(e)
        return nil
      end

      if response.body.nil? || response.body.empty? || response.code != 200
        logger.debug "TF Serving: status_code: 500, message: No response from ranker!"
        report_error(InvalidContainerResponse.new, extra: { response: response })
        return nil
      else
        logger.debug "TF Serving: status_code: #{response.code}, message: #{response.message}"
      end

      JSON.parse(response.body).fetch("results")
    end

    def logger
      Logging.logger.root
    end
  end
end
