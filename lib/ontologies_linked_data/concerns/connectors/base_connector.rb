require 'net/http'
require 'json'

module Connectors
  class ConnectorError < StandardError; end

  class BaseConnector
    attr_reader :params

    def initialize
      @params = {}
    end

    def fetch_projects(params)
      @params = params
      url = build_url
      query_params = build_params(params)      
      uri = URI(url)
      uri.query = URI.encode_www_form(query_params)
      response = fetch_data(uri)
      map_response(response)
    end

    private
    def fetch_data(uri)
      begin        
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == 'https')
        request = Net::HTTP::Get.new(uri)
        response = http.request(request)
        handle_response(response)
      rescue StandardError => e
        raise ConnectorError, "External API error: #{e.message}"
      end
    end
    
    def handle_response(response)      
      case response
      when Net::HTTPSuccess
        content_type = response.content_type || ''
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
        raise ConnectorError, "External API returned error: #{response.code}"
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
      case source&.upcase
      when 'ANR'
        AnrConnector.new
      when 'CORDIS'
        CordisConnector.new
      else
        raise ConnectorError, "Unsupported source: #{source}"
      end
    end
  end
end