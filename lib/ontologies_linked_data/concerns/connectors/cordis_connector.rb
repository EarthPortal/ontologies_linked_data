require 'rexml/document'

module Connectors
  class CordisConnector < BaseConnector
    private

    def build_url
      if @params[:id]
        base_url = connector_config[:base_url] 
        "#{base_url}/#{@params[:id]}"
      else
        connector_config[:search_url]
      end
    end

    def build_params(project_id = nil, project_acronym = nil)
      if project_id
        { format: 'xml' }
      elsif project_acronym
        acronym = project_acronym.to_s.strip
        raise ConnectorError, "Acronym must be at least 3 characters long" if acronym.length < 3
        
        query = "contenttype='project'"
        query += " AND (acronym='#{acronym}*' OR acronym='* #{acronym}*' OR acronym='*-#{acronym}*' OR acronym='*_#{acronym}*')"
        # query += " AND (acronym='#{acronym}*')"

        {
          q: query,
          p: 1,
          num: 10,
          format: 'xml'
        }
      else
        raise ConnectorError, "Either project ID or acronym is required"
      end
    end

    def map_single_project(xml_project)
      project = LinkedData::Models::Project.new
      
      project.source = connector_config[:source]
      project.type = connector_config[:project_type]
      project.acronym = xml_project.elements['acronym']&.text
      project.name = xml_project.elements['title']&.text
      project.description = xml_project.elements['objective']&.text
      
      # Try to get the grantDoi first for homepage
      grant_doi = xml_project.elements['identifiers/grantDoi']&.text
      if grant_doi
        project.homePage = "https://doi.org/#{grant_doi}"
      elsif url_xpath = connector_config[:project_url_xpath]
        url_element = REXML::XPath.first(xml_project, url_xpath)
        project.homePage = url_element&.text || build_default_homepage(xml_project)
      else
        project.homePage = build_default_homepage(xml_project)
      end
      
      project.created = DateTime.now
      project.updated = DateTime.now
      
      # Rest of the method remains unchanged
      start_date_field = connector_config[:start_date_field] 
      end_date_field = connector_config[:end_date_field]
      
      if xml_project.elements[start_date_field]&.text
        begin
          project.start_date = DateTime.parse(xml_project.elements[start_date_field].text)
        rescue ArgumentError
          # Invalid date format
        end
      end
      
      if xml_project.elements[end_date_field]&.text
        begin
          project.end_date = DateTime.parse(xml_project.elements[end_date_field].text)
        rescue ArgumentError
          # Invalid date format
        end
      end
      
      keyword_field = connector_config[:keyword_field] 
      project.keywords = extract_keywords(xml_project)
      
      grant_number = connector_config[:grant_number]
      project.grant_number = xml_project.elements[grant_number]&.text
      
      coord_data = extract_coordinator(xml_project)
      if coord_data
        organization = LinkedData::Models::Agent.new
        organization.agentType = "organization"
        organization.name = coord_data[:name]
        organization.homepage = coord_data[:homepage]
        project.organization = organization
      end
      
      funder_config = connector_config[:funder]
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
    
    def map_response(xml_data)
      begin
        doc = REXML::Document.new(xml_data)
        
        if doc.elements['project'] && @params[:id]
          project_element = doc.elements['project']
          
          if !project_element || !project_element.elements[connector_config[:grant_number]]&.text
            raise ProjectNotFoundError, "No projects found matching search criteria"
          end
          
          project = map_single_project(project_element)
          return {
            totalCount: 1,
            collection: [project]
          }
        elsif doc.elements['response']
          total_hits = doc.elements['response/result/header/totalHits']&.text.to_i
          
          if total_hits == 0
            raise ProjectNotFoundError, "No projects found matching search criteria"
          end
          
          projects = []
          
          REXML::XPath.each(doc, '//hit/project') do |project_xml|
            projects << map_single_project(project_xml)
          end
          
          
          if projects.empty?
            raise ProjectNotFoundError, "No projects found matching search criteria"
          end
          
          return {
            totalCount: projects.length, 
            collection: projects
          }
        else
          error_element = doc.elements['error'] || doc.elements['//error']
          if error_element&.text&.include?("not found")
            raise ProjectNotFoundError, "No projects found matching search criteria"
          else
            raise ConnectorError, "Invalid XML response format"
          end
        end
        
      rescue REXML::ParseException => e
        raise ConnectorError, "Failed to parse XML: #{e.message}"
      end
    end

    def build_default_homepage(xml_project)
      base_url = connector_config[:base_url]
      grant_number = connector_config[:grant_number]
      project_id = xml_project.elements[grant_number]&.text
      
      "#{base_url}/#{project_id}"
    end
    
    def extract_keywords(xml_project)
      keywords_text = xml_project.elements['keywords']&.text
      return [] unless keywords_text
      keywords_text.split(',').map(&:strip)
    end

    def extract_coordinator(xml_project)
      coordinator = REXML::XPath.first(xml_project, ".//relations/associations/organization[@type='coordinator']")
      
      if coordinator
        return {
          name: coordinator.elements['legalName']&.text,
          homepage: coordinator.elements['address/url']&.text
        }
      end
      
      # Fallback to the original coordinator extraction if available
      coord_xpath = connector_config[:coordinator_xpath]
      if coord_xpath
        coord = REXML::XPath.first(xml_project, coord_xpath)
        if coord
          name_element = connector_config[:coordinator_name_element]
          url_element = connector_config[:coordinator_url_element]
          
          return {
            name: coord.elements[name_element]&.text,
            homepage: coord.elements[url_element]&.text
          }
        end
      end
      nil
    end
  end
end