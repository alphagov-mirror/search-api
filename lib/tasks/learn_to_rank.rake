require "base64"
require "csv"
require "fileutils"
require "json"
require "rummager"
require "zip"
require "analytics/popular_queries"
require "relevancy/load_judgements"

namespace :learn_to_rank do
  desc "Run the full data training pipeline: fetch BigQuery data, generate SVM files, upload to S3.  This costs money!"
  task :data_pipeline, [:bigquery_credentials, :s3_bucket] do |_, args|
    assert_ltr!
    LearnToRank::DataPipeline.perform_sync(
      JSON.parse(Base64.decode64(args.bigquery_credentials)),
      args.s3_bucket,
    )
  end

  desc "Fetch data from BigQuery.  This costs money!"
  task :fetch_bigquery_export, [:credentials] do |_, args|
    assert_ltr!
    data = LearnToRank::Bigquery.fetch(JSON.parse(Base64.decode64(args.credentials)))
    export_to_csv(data, "bigquery-export")
  end

  desc "Export a CSV of relevancy judgements generated from CTR on popular queries"
  task :generate_relevancy_judgements, [:queries_filepath] do |_, args|
    assert_ltr!
    queries = LearnToRank::LoadSearchQueries.from_csv(args.queries_filepath)
    generator = LearnToRank::RelevancyJudgements.new(queries: queries)
    judgements = generator.relevancy_judgements
    export_to_csv(judgements, "autogenerated_relevancy_judgements")
  end

  desc "Export a CSV of SVM-formatted relevancy judgements for training a model"
  task :generate_training_dataset, [:judgements_filepath, :svm_dir] do |_, args|
    assert_ltr!

    csv = args.judgements_filepath || "tmp/autogenerated_relevancy_judgements.csv"
    svm_dir = args.svm_dir || "tmp/ltr_data"
    FileUtils.mkdir_p svm_dir

    judgements_data = Relevancy::LoadJudgements.from_csv(csv)
    judgements = LearnToRank::EmbedFeatures.new(judgements_data).augmented_judgements
    svm = LearnToRank::JudgementsToSvm.new(judgements).svm_format.group_by { |row| row.split(" ")[1] }

    File.open("#{svm_dir}/train.txt", "wb") do |train|
      File.open("#{svm_dir}/validate.txt", "wb") do |validate|
        File.open("#{svm_dir}/test.txt", "wb") do |test|
          svm.values.shuffle.each.with_index do |query_set, index|
            # 70% in train 20% in test, 10% in validate
            file = [train, train, train, train, train, train, train, test, test, validate][index % 10]
            query_set.each { |row| file.puts(row) }
          end
        end
      end
    end
  end

  desc "Pull learn to rank model from S3"
  task :pull_model, [:model_filename] do |_, args|
    bucket_name = ENV["AWS_S3_RELEVANCY_BUCKET_NAME"]
    raise "Missing required AWS_S3_RELEVANCY_BUCKET_NAME" if bucket_name.blank?

    models_dir = ENV["TENSORFLOW_MODELS_DIRECTORY"]
    raise "Please specify the Tensorflow models directory" if models_dir.blank?

    prefix            = "ltr"
    model_filename    = args.model_filename || fetch_latest_model_filename(bucket_name, prefix)

    if model_filename.blank?
      puts "No model file found. Skipping pull from S3 ..."
      next # gracefully exit rake task with code 0
    end

    model_version     = model_filename.to_i.to_s
    ltr_models_dir    = File.join(models_dir, "ltr")
    model_version_dir = "#{ltr_models_dir}/#{model_version}"

    if Dir.exist?(model_version_dir)
      puts "Model version #{model_version} already present at #{model_version_dir}. Skipping pull from S3 ..."
      next
    end

    pull_model_from_s3(bucket_name: bucket_name,
                       key: "#{prefix}/#{model_filename}",
                       ltr_models_dir: ltr_models_dir)
  end

  namespace :reranker do
    desc "Train a reranker model with relevancy judgements"
    task :train, [:svm_dir, :model_dir] do |_, args|
      assert_ltr!

      model_dir = args.model_dir || "tmp/libsvm"
      svm_dir = args.svm_dir || "tmp/ltr_data"
      sh "env OUTPUT_DIR=#{model_dir} TRAIN=#{svm_dir}/train.txt VALI=#{svm_dir}/validate.txt TEST=#{svm_dir}/test.txt ./ltr_scripts/train.sh"
    end

    desc "Serves a trained model"
    task :serve, [:model_dir] do |_, args|
      assert_ltr!

      model_dir = args.model_dir || "tmp/libsvm"
      sh "env EXPORT_PATH=#{__dir__}/../../#{model_dir} ./ltr_scripts/serve.sh"
    end

    desc "Evaluate search performance using nDCG with and without the model"
    task :evaluate, [:relevancy_judgements] do |_, args|
      assert_ltr!

      ndcg_at = "10"

      csv = args.relevancy_judgements
      rounds = [nil, "relevance:B"]
      results, results_with_model = rounds.map do |ab_test_round|
        judgements = Relevancy::LoadJudgements.from_csv(csv)
        evaluator = Evaluate::Ndcg.new(judgements, ab_test_round)
        evaluator.compute_ndcg
      end

      merged = results.keys.each_with_object({}) do |query, hsh|
        hsh[query] = {
          without: results[query],
          with_model: results_with_model[query],
        }
      end

      maxlen = results.keys.map { |query, _| query.length }.max
      score_maxlen = results.values.map { |score, _| score[ndcg_at].to_s.length }.max

      merged.map do |(query, scores)|
        winning = scores[:without][ndcg_at] <= scores[:with_model][ndcg_at] ? "√" : "x"
        puts "#{winning} #{(query + ':').ljust(maxlen + 1)} #{scores[:without][ndcg_at].to_s.ljust(score_maxlen + 1)} #{scores[:with_model][ndcg_at]}"
      end

      winning = merged.dig("average_ndcg", :without, ndcg_at) <= merged.dig("average_ndcg", :with_model, ndcg_at)

      puts "---"
      puts "without model score: #{merged['average_ndcg'][:without][ndcg_at]}"
      puts "with model score: #{merged['average_ndcg'][:with_model][ndcg_at]}"
      puts "Without model: #{merged['average_ndcg'][:without]}"
      puts "With model: #{merged['average_ndcg'][:with_model]}"
      puts "The model has a #{winning ? 'good' : 'bad'} score"
    end
  end

  def assert_ltr!
    raise 'set $ENABLE_LTR to "true" to use learn_to_rank' unless Search::RelevanceHelpers.ltr_enabled?
  end

  def export_to_csv(hash, filename)
    CSV.open("tmp/#{filename}.csv", "wb") do |csv|
      csv << hash.first.keys
      hash.each do |row|
        csv << row.values
      end
    end
  end

  def fetch_latest_model_filename(bucket_name, prefix)
    begin
      s3_objects  = Aws::S3::Bucket.new(bucket_name).objects(prefix: prefix)
      model_files = s3_objects.map { |object| object.key.delete("#{prefix}/") }
      model_files.max_by(&:to_i)
    rescue StandardError => e
      puts "There was error fetching the latest model file from S3: #{e.message}"
    end
  end

  def pull_model_from_s3(bucket_name:, key:, ltr_models_dir:)
    tmpdir          = Dir.mktmpdir
    response_target = "#{tmpdir}/latest_model"

    begin
      puts "Pulling model: #{key} ..."

      s3_object = Aws::S3::Object.new(bucket_name: bucket_name, key: key)
      s3_object.get(response_target: response_target)

      Zip::File.open(response_target) do |zip_file|
        zip_file.each do |source_file|
          destination_path = File.join(ltr_models_dir, source_file.name)
          puts "Extracting archive to #{destination_path} ..."
          zip_file.extract(source_file, destination_path) unless File.exist?(destination_path)
        end
      end
    rescue StandardError => e
      puts "There was an error pulling the model from S3: #{e.message}"
    ensure
      FileUtils.remove_entry tmpdir
    end
  end
end
