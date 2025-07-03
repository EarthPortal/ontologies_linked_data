module LinkedData
  module Models
    class Project < LinkedData::Models::Base
      model :project, :name_with => :acronym,
            rdf_type: lambda { |*x| RDF::URI.new('https://schema.org/ResearchProject') }

      # Required attributes
      attribute :acronym, enforce: [:unique, :existence, lambda { |inst,attr| validate_acronym(inst,attr) }], 
                namespace: :metadata, property: :acronym
                
      attribute :creator, enforce: [:existence, :user, :list], 
                namespace: :schema, property: :creator
                
      attribute :created, enforce: [:date_time], :default => lambda {|x| DateTime.now },
                namespace: :schema, property: :dateCreated
                
      attribute :updated, enforce: [:date_time], :default => lambda {|x| DateTime.now },
                namespace: :schema, property: :dateModified
                
      attribute :type, enforce: [:existence], enforcedValues: %w[FundedProject NonFundedProject],
                namespace: :metadata, property: :projectType
                
      attribute :name, enforce: [:existence],
                namespace: :schema, property: :legalName
                
      attribute :homePage, enforce: [:uri, :existence],
                namespace: :foaf, property: :homepage
                
      attribute :description, enforce: [:existence],
                namespace: :schema, property: :description
                
      attribute :ontologyUsed, enforce: [:ontology, :list, :existence],
                namespace: :metadata, property: :ontologyUsed
                
      attribute :source, enforcedValues: lambda { self.project_sources },
                namespace: :schema, property: :isBasedOn

      attribute :keywords, enforce: [:list, :existence],
                namespace: :schema, property: :keywords
      
      # Optional attributes
      attribute :contact, enforce: [:Agent, :list],
                namespace: :schema, property: :contactPoint
                
      attribute :organization, enforce: [:Agent],
                namespace: :org, property: :memberOf
                
      attribute :logo, enforce: [:uri],
                namespace: :schema, property: :logo
      
      attribute :grant_number, enforce: [:string],
                namespace: :schema, property: :identifier
                
      attribute :start_date, enforce: [:date_time],
                namespace: :schema, property: :startDate
                
      attribute :end_date, enforce: [:date_time],
                namespace: :schema, property: :endDate
                
      attribute :funder, enforce: [:Agent],
                namespace: :schema, property: :funder

      embed :contact, :organization, :funder
      serialize_default :acronym, :type, :name, :homePage, :description, 
                      :ontologyUsed, :created, :updated, :keywords,
                      :contact, :organization, :grant_number, :start_date, 
                      :end_date, :funder, :logo, :source, :creator

      write_access :creator
      access_control_load :creator

      def self.validate_acronym(inst, attr)
        inst.bring(attr) if inst.bring?(attr)
        acronym = inst.send(attr)

        return [] if acronym.nil?

        errors = []

        if acronym.match(/\A[^a-z^A-Z]{1}/)
          errors << [:start_with_letter, "`acronym` must start with a letter"]
        end

        if acronym.match(/[a-z]/)
          errors << [:capital_letters, "`acronym` must be all capital letters"]
        end

        if acronym.match(/[^-_0-9a-zA-Z]/)
          errors << [:special_characters, "`acronym` must only contain the following characters: -, _, letters, and numbers"]
        end

        if acronym.match(/.{17,}/)
          errors << [:length, "`acronym` must be sixteen characters or less"]
        end

        return errors.flatten
      end

      def self.project_sources
        LinkedData.settings.connectors[:available_sources].keys
      end
    end
  end
end