require_relative 'base_connector'

module Connectors
  class AnrConnector < BaseConnector
    private
    
    def build_url
      dataset_id = params[:dataset_id]
      raise ConnectorError, "Dataset ID is required" unless dataset_id
      base_url = LinkedData.settings.anr_connector[:base_url]
      "#{base_url}/#{dataset_id}/records"
    end

    def build_params(params)
      raise ConnectorError, "Query parameter is required" unless params[:query]

      # validate query length
      query = params[:query].to_s.strip
      min_query_length = LinkedData.settings.anr_connector[:min_query_length]
      raise ConnectorError, "Query must be at least #{min_query_length} characters long" if query.length < min_query_length
      
      {
        limit: params[:limit] || LinkedData.settings.anr_connector[:default_limit],
        where: build_query_conditions(params)
      }
    end

    def build_query_conditions(params)
      mapping = get_dataset_mapping
      config = LinkedData.settings.anr_connector
      query_format = config[:query_format] || "LIKE '*%s*'"
      if params[:query]
        query_term = params[:query]
        search_fields = config[:search_fields] || [:acronym, :grant_number]
        field_conditions = search_fields.map do |field_key|
          field_name = mapping[field_key]
          next unless field_name
          "#{field_name} #{query_format.gsub('%s', query_term)}"
        end.compact
        
        "(#{field_conditions.join(' OR ')})"
      else
        raise ConnectorError, "Query parameter is required"
      end
    end
    
    def get_dataset_mapping
      dataset_mappings = LinkedData.settings.anr_dataset_mappings
      mapping = dataset_mappings[params[:dataset_id]]
      raise ConnectorError, "Unsupported dataset: #{params[:dataset_id]}" unless mapping
      mapping
    end

    def find_matching_project(results, mapping)
      if params[:id]
        results.find { |r| r[mapping[:grant_number]] == params[:id] }
      elsif params[:acronym]
        results.find { |r| r[mapping[:acronym]] == params[:acronym] }
      end
    end

    def build_project_data(result, mapping)
      project = LinkedData::Models::Project.new
      
      project.source = LinkedData.settings.anr_connector[:source] || 'ANR'
      project.type = LinkedData.settings.anr_connector[:project_type] || 'FundedProject'
      project.acronym = result[mapping[:acronym]]
      project.name = result[mapping[:name]]
      project.description = get_description(result, mapping)
      project.homePage = result[mapping[:homepage]]
      
      project.created = DateTime.now
      project.updated = DateTime.now
      
      if mapping[:start_date] && result[mapping[:start_date]]
        begin
          project.start_date = DateTime.parse(result[mapping[:start_date]])
        rescue ArgumentError
          # Invalid date format
        end
      end
      
      if mapping[:end_date] && result[mapping[:end_date]]
        begin
          project.end_date = DateTime.parse(result[mapping[:end_date]])
        rescue ArgumentError
          # Invalid date format
        end
      end
      
      project.grant_number = result[mapping[:grant_number]]
      
      funder_config = LinkedData.settings.anr_connector[:funder]
      if funder_config
        funder = LinkedData::Models::Agent.new
        funder.agentType = funder_config[:agentType]  
        funder.name = funder_config[:name]
        funder.homepage = funder_config[:homepage] if funder_config[:homepage]
        
        project.funder = funder
      end
      
      project.ontologyUsed = []
      
      project
    end

    def map_response(data)
      raise ConnectorError, "No projects found matching search criteria" if data['results'].empty?      
      mapping = get_dataset_mapping
      data['results'].map { |result| build_project_data(result, mapping) }
    end

    def get_description(result, mapping)
      # Try the primary description field
      description = result[mapping[:description]] if mapping[:description]
      
      # Try fallbacks if primary is nil
      if description.nil?
        fallbacks = LinkedData.settings.anr_connector[:description_fallbacks] || {}
        dataset_fallbacks = fallbacks[params[:dataset_id]] || []
        
        dataset_fallbacks.each do |fallback_field|
          description = result[fallback_field]
          break if description
        end
      end
      
      description
    end
  end
end