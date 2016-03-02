require_relative "registry"

module Search
  class Registries < Struct.new(:search_server, :search_config)
    def [](name)
      as_hash[name]
    end

    def as_hash
      @registries ||= {
        organisations: organisations,
        specialist_sectors: specialist_sectors,
        topics: registry_for_document_format('topic'),

        # Whitehall has a thing called `topic`, which is being renamed to "policy
        # area", because there already are seven things called "topic". Until
        # Whitehall publishes the policy areas with format "policy_area" rather
        # than "topic", we will expand `policy_areas` with data from documents
        # with format `topic`.
        policy_areas: registry_for_document_format('topic'),
        document_series: registry_for_document_format('document_series'),
        document_collections: registry_for_document_format('document_collection'),
        world_locations: registry_for_document_format('world_location'),
        people: registry_for_document_format('person'),
      }
    end

  private

    def organisations
      BaseRegistry.new(
        index,
        field_definitions,
        "organisation",
        %w{slug link title acronym organisation_type organisation_state}
      )
    end

    def specialist_sectors
      BaseRegistry.new(
        search_server.index_for_search(settings.search_config.content_index_names),
        field_definitions,
        "specialist_sector"
      )
    end

    def registry_for_document_format(format)
      BaseRegistry.new(index, field_definitions, format)
    end

    def index
      search_server.index_for_search([settings.search_config.registry_index])
    end

    def field_definitions
      @field_definitions ||= search_server.schema.field_definitions
    end
  end
end