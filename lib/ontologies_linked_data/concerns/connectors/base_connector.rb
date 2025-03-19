require 'faraday'
require 'json'

module Connectors
  class ConnectorError < StandardError; end

  class BaseConnector
    attr_reader :params
    attr_accessor :connector_key

    def initialize
      @params = {}
      @connector_key = nil
    end

    def connector_config
      return {} unless @connector_key
      LinkedData.settings.connectors[:configs][@connector_key] || {}
    end

    def fetch_projects(params)
      @params = params 
      project_id = params[:id]
      project_acronym = params[:acronym]
      
      url = build_url
      query_params = build_params(project_id, project_acronym)
      response = fetch_data(url, query_params)
      map_response(response)
    end

    private
    def fetch_data(url, query_params)
      begin
        response = Faraday.new(url: url).get do |req|
          req.params.merge!(query_params)
        end
        
        handle_response(response)
      rescue StandardError => e
        raise ConnectorError, "External API error: #{e.message}"
      end
    end
    
    def handle_response(response)
      if response.success?
        content_type = response.headers['Content-Type'] || ''
        
        if content_type.include?('xml')
          response.body 
        elsif content_type.include?('json')
          JSON.parse(response.body)
        else
          # try JSON first fallback to raw body
          begin
            JSON.parse(response.body)
          rescue JSON::ParserError
            response.body
          end
        end
      else
        error_message = "External API returned error: #{response.status}"
        raise ConnectorError, error_message
      end
    end

    # To be implemented by child classes
    def build_url
      raise NotImplementedError
    end

    def build_params(params)
      raise NotImplementedError
    end

    def map_response(data)
      raise NotImplementedError
    end
  end
  
  class Factory
    def self.create(source)
      source_key = source&.upcase
      if LinkedData.settings.connectors && 
         LinkedData.settings.connectors[:available_sources] &&
         LinkedData.settings.connectors[:available_sources][source_key]
        connector = LinkedData.settings.connectors[:available_sources][source_key].new
        connector.connector_key = source_key
        return connector
      end
      raise ConnectorError, "Unsupported source: #{source}"
    end
  end
end