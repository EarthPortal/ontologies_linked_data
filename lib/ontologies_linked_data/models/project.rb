module LinkedData
  module Models
    class Project < LinkedData::Models::Base
      model :project, :name_with => :acronym
      
      def self.project_sources
        LinkedData.settings.project_sources
      end

      def self.project_types
        LinkedData.settings.project_types
      end

      # Required attributes
      attribute :acronym, enforce: [:unique, :existence]
      attribute :creator, enforce: [:existence, :user, :list]
      attribute :created, enforce: [:date_time], :default => lambda {|x| DateTime.now }
      attribute :updated, enforce: [:date_time], :default => lambda {|x| DateTime.now }
      attribute :type, enforce: [:existence], enforcedValues: lambda { self.project_types }
      attribute :name, enforce: [:existence]
      attribute :homePage, enforce: [:uri, :existence]
      attribute :description, enforce: [:existence]
      attribute :ontologyUsed, enforce: [:ontology, :list, :existence]
      attribute :source, enforce: [:existence], enforcedValues: lambda { self.project_sources }
      
      # Optional attributes
      attribute :keywords, enforce: [:list]
      attribute :contact, enforce: [:Agent]
      attribute :institution, enforce: [:Agent]
      attribute :coordinator, enforce: [:Agent]
      attribute :logo, enforce: [:uri]
      
      # Conditional attributes (required for ANR/CORDIS)
      attribute :grant_number, enforce: [:string]
      attribute :start_date, enforce: [:date_time]
      attribute :end_date, enforce: [:date_time]
      attribute :funder, enforce: [:Agent]
      

      embed :contact, :institution, :funder, :coordinator
      serialize_default :acronym, :type, :name, :homepage, :description, 
                      :ontologyUsed, :created, :updated, :keywords,
                      :contact, :institution, :grant_number, :start_date, 
                      :end_date, :funder, :coordinator, :logo

      write_access :creator
      access_control_load :creator

      def self.valid_project_type?(type)
        self.project_types.include?(type)
      end
    end
  end
end