module LinkedData
  module Models
    class Project < LinkedData::Models::Base
      model :project, :name_with => :acronym
      
      def self.project_sources
        LinkedData.settings.connectors[:available_sources].keys
      end

      # Required attributes
      attribute :acronym, enforce: [:unique, :existence]
      attribute :creator, enforce: [:existence, :user, :list]
      attribute :created, enforce: [:date_time], :default => lambda {|x| DateTime.now }
      attribute :updated, enforce: [:date_time], :default => lambda {|x| DateTime.now }
      attribute :type, enforce: [:existence], enforcedValues: %w[FundedProject NonFundedProject]
      attribute :name, enforce: [:existence]
      attribute :homePage, enforce: [:uri, :existence]
      attribute :description, enforce: [:existence]
      attribute :ontologyUsed, enforce: [:ontology, :list, :existence]
      attribute :source, enforce: [:existence], enforcedValues: lambda { self.project_sources }
      
      # Optional attributes
      attribute :keywords, enforce: [:list]
      attribute :contact, enforce: [:Agent]
      attribute :organization, enforce: [:Agent]
      attribute :logo, enforce: [:uri]
      
      # Conditional attributes
      attribute :grant_number, enforce: [:string]
      attribute :start_date, enforce: [:date_time]
      attribute :end_date, enforce: [:date_time]
      attribute :funder, enforce: [:Agent]
      

      embed :contact, :organization, :funder
      serialize_default :acronym, :type, :name, :homePage, :description, 
                      :ontologyUsed, :created, :updated, :keywords,
                      :contact, :organization, :grant_number, :start_date, 
                      :end_date, :funder, :logo

      write_access :creator
      access_control_load :creator
    end
  end
end