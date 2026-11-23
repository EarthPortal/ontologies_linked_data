module LinkedData
  module Models
    module Users
      class Role < LinkedData::Models::Base
        DEFAULT = "LIBRARIAN"
        # CURATOR: added after the existing values, created in the triplestore at the first use (enum)
        VALUES = ["LIBRARIAN", "ADMINISTRATOR", "DEVELOPER", "CURATOR"]
        ADMIN = "ADMINISTRATOR"
        # The rights of a librarian, plus the curation of the metadata of every ontology (Curation page of the UI)
        CURATOR = "CURATOR"

        model :role, name_with: :role
        attribute :role, enforce: [:unique, :existence]

        enum VALUES

        def self.default
          return find(DEFAULT).include(:role).first
        end

      end
    end
  end
end
