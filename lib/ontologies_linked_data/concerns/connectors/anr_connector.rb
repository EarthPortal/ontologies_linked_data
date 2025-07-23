require_relative 'base_connector'

module Connectors
  class AnrConnector < BaseConnector
    private
    
    def build_url
      connector_config[:base_url] || 
        raise(ConnectorError, "BASE URL not configured")
    end

    def build_params(project_id = nil, project_acronym = nil)
      if !project_id && !project_acronym
        raise ConnectorError, "Either project ID or acronym is required"
      end      
      {
        limit: 10,
        where: build_query_conditions(project_id, project_acronym)
      }
    end

    def build_query_conditions(project_id, project_acronym)
      mapping = get_dataset_mapping
      config = connector_config
      query_format = config[:query_format]
      
      if project_id
        # exact ID match
        id = project_id.to_s.strip
        field_name = mapping[:grant_number]
        raise ConnectorError, "Grant number field not defined in mapping" unless field_name
        
        "#{field_name} = '#{id}'"
      elsif project_acronym
        # acronym search 
        acronym_term = project_acronym.to_s.strip
        raise ConnectorError, "Acronym must be at least 3 characters long" if acronym_term.length < 3
        
        field_name = mapping[:acronym]
        raise ConnectorError, "Acronym field not defined in mapping" unless field_name
        
        "#{field_name} LIKE '*#{acronym_term}*'"
      else
        raise ConnectorError, "Either project ID or acronym is required"
      end
    end
        
    def get_dataset_mapping
      connector_config[:field_mappings]
    end

    def find_matching_project(results, mapping)
      if @params[:id]
        results.find { |r| r[mapping[:grant_number]] == @params[:id] }
      elsif @params[:acronym]
        results.find { |r| r[mapping[:acronym]] == @params[:acronym] }
      end
    end

    def build_project_data(result, mapping)
      project = LinkedData::Models::Project.new
      
      project.source = connector_config[:source]
      project.type = connector_config[:project_type] || 'FundedProject'
      raw_acronym = result[mapping[:acronym]]
      if raw_acronym
        project.acronym = raw_acronym.upcase.gsub(' ', '-')
      end
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
      
      funder_id = connector_config[:funder]
      if funder_id
        project.funder = RDF::URI.new(funder_id)  
      end
      
      project.ontologyUsed = []
      
      project
    end

    def map_response(data)
      raise ProjectNotFoundError, "No projects found matching search criteria" if data['results'].empty?
      
      mapping = get_dataset_mapping
      projects = data['results'].map { |result| build_project_data(result, mapping) }
      
      {
        totalCount: projects.length,
        collection: projects
      }
    end

    def get_description(result, mapping)
      # Try the primary description field
      description = result[mapping[:description]] if mapping[:description]
      
      # Try fallbacks if primary is nil
      if description.nil?
        fallbacks = connector_config[:description_fallbacks] || []
        
        fallbacks.each do |fallback_field|
          description = result[fallback_field]
          break if description
        end
      end
      
      description
    end
  end
end