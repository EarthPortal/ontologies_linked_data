module LinkedData
  module Models
    class ExternalToolType < LinkedData::Models::Base
      VALUES = ["EDITOR", "VALIDATOR"]

      model :external_tool_type, name_with: :type
      attribute :type, enforce: [:unique, :existence]

      enum VALUES
    end

    class ExternalTool < LinkedData::Models::Base
      model :external_tool, name_with: :name
      attribute :name, enforce: [:unique, :existence]
      attribute :title, enforce: [:existence]
      attribute :homepage, enforce: [:existence, :uri]
      attribute :externalToolType, enforce: [:existence, :external_tool_type]
      attribute :created, enforce: [:date_time], :default => lambda { |record| DateTime.now }

      serialize_default :name, :title, :homepage, :externalToolType, :created
      embed_values externalToolType: [:type]
      cache_timeout 86400
    end
  end
end
