require 'rexml/document'

module Connectors
  class CordisConnector < BaseConnector
    private

    def build_url
      project_id = params[:id]
      raise ConnectorError, "Project ID is required" unless project_id
      "https://cordis.europa.eu/project/id/#{project_id}"
    end

    def build_params(params)
      {format: 'xml'}
    end

    def map_response(xml_data)
      begin
        doc = REXML::Document.new(xml_data)
        project = doc.elements['project']
        
        raise ConnectorError, "Invalid XML response" unless project
    
        coordinator = extract_coordinator(project)
        project_url = extract_project_url(project)
        keywords = extract_keywords(project)
        {
          source: 'CORDIS',
          type: 'FundedProject',
          source: 'CORDIS',
          acronym: project.elements['acronym']&.text,
          name: project.elements['title']&.text,
          description: project.elements['objective']&.text,
          homepage: project_url,
          ontologyUsed: [],  
          creator: nil,      
          created: DateTime.now,  
          updated: DateTime.now, 
          keywords: keywords,
          contact: nil,     
          institution: nil,  
          coordinator: coordinator,
          logo: nil,       
          grant_number: project.elements['id']&.text,
          start_date: project.elements['startDate']&.text,
          end_date: project.elements['endDate']&.text,
          funder: {
            type: 'Agent',
            name: "European Commission",
            homepage: "https://ec.europa.eu"
          }
        }
      rescue REXML::ParseException => e
        raise ConnectorError, "Failed to parse XML: #{e.message}"
      end
    end

    private

    def extract_keywords(project)
      keywords_text = project.elements['keywords']&.text
      return [] unless keywords_text
      keywords_text.split(',').map(&:strip)
    end

    private

    def extract_coordinator(project)
      coord = REXML::XPath.first(project, ".//organization[@type='coordinator']")
      return nil unless coord
      {
        name: coord.elements['legalName']&.text,
        homepage: coord.elements['address/url']&.text
      }
    end

    def extract_project_url(project)
      web_link = REXML::XPath.first(project, ".//webLink[@represents='project']/physUrl")
      web_link&.text || "https://cordis.europa.eu/project/id/#{project.elements['id']&.text}"
    end
  end
end