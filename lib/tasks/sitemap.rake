require "aws-sdk-s3"
require "sitemap/uploader"

namespace :sitemap do
  desc "Generate new sitemap files and upload to S3"
  task :generate_and_upload do
    @bucket_name = ENV["AWS_S3_SITEMAPS_BUCKET_NAME"]
    raise "Missing required AWS_S3_SITEMAPS_BUCKET_NAME" if @bucket_name.nil?

    Sitemap::Generator.new(
      SearchConfig.default_instance,
      Sitemap::Uploader.new(@bucket_name),
      Time.now.utc,
    ).run
  end
end
