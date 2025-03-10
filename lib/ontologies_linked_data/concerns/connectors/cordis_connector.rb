require 'rexml/document'

module Connectors
  class CordisConnector < BaseConnector
    private

    def build_url
      project_id = params[:id]
      raise ConnectorError, "Project ID is required" unless project_id
      base_url = LinkedData.settings.cordis_connector[:base_url]
      "#{base_url}/#{project_id}"
    end

    def build_params(params)
      {format: LinkedData.settings.cordis_connector[:format] || 'xml'}
    end

    def map_response(xml_data)
      begin
        doc = REXML::Document.new(xml_data)
        xml_project = doc.elements['project']
        
        raise ConnectorError, "Invalid XML response" unless xml_project
        project = LinkedData::Models::Project.new
        
        project.source = LinkedData.settings.cordis_connector[:source] || 'CORDIS'
        project.type = LinkedData.settings.cordis_connector[:project_type] || 'FundedProject'
        project.acronym = xml_project.elements['acronym']&.text
        project.name = xml_project.elements['title']&.text
        project.description = xml_project.elements['objective']&.text
        project.homePage = LinkedData.settings.cordis_connector[:project_url_xpath]
        
        project.created = DateTime.now
        project.updated = DateTime.now
        
        if xml_project.elements['startDate']&.text
          begin
            project.start_date = DateTime.parse(xml_project.elements['startDate'].text)
          rescue ArgumentError
            # Invalid date format
          end
        end
        
        if xml_project.elements['endDate']&.text
          begin
            project.end_date = DateTime.parse(xml_project.elements['endDate'].text)
          rescue ArgumentError
            # Invalid date format
          end
        end
        
        project.keywords = extract_keywords(xml_project)
        
        project.grant_number = xml_project.elements['id']&.text
        
        funder_config = LinkedData.settings.cordis_connector[:funder]
        if funder_config
          funder = LinkedData::Models::Agent.new
          funder.agentType = "organization"
          funder.name = funder_config[:name]
          funder.homepage = funder_config[:homepage] if funder_config[:homepage]
          
          project.funder = funder
        end
        
        coordinator_data = extract_coordinator(xml_project)
        if coordinator_data
          coordinator = LinkedData::Models::Agent.new
          coordinator.agentType = "organization"
          coordinator.name = coordinator_data[:name]
          coordinator.homepage = coordinator_data[:homepage]
          project.coordinator = coordinator
        end
        
        project.ontologyUsed = []
        
        project
        
      rescue REXML::ParseException => e
        raise ConnectorError, "Failed to parse XML: #{e.message}"
      end
    end

    def extract_keywords(xml_project)
      keywords_text = xml_project.elements['keywords']&.text
      return [] unless keywords_text
      keywords_text.split(',').map(&:strip)
    end

    def extract_coordinator(xml_project)
      coord_xpath = LinkedData.settings.cordis_connector[:coordinator_xpath] 
      
      coord = REXML::XPath.first(xml_project, coord_xpath)
      return nil unless coord
      
      name_element = LinkedData.settings.cordis_connector[:coordinator_name_element]
      url_element = LinkedData.settings.cordis_connector[:coordinator_url_element] 
      
      {
        name: coord.elements[name_element]&.text,
        homepage: coord.elements[url_element]&.text
      }
    end
  end
end