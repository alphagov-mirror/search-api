require "govuk_app_config"

GovukUnicorn.configure(self)

working_directory File.dirname(File.dirname(__FILE__))
worker_processes 6
