module LinkedData
  module Models
    class ExternalTool < LinkedData::Models::Base
      model :external_tool, name_with: :name
      attribute :name, enforce: [:unique, :existence]
      attribute :title, enforce: [:existence]
      attribute :homepage, enforce: [:existence, :uri]
      attribute :created, enforce: [:date_time], :default => lambda { |record| DateTime.now }

      serialize_default :name, :title, :homepage, :created
      cache_timeout 86400
    end
  end
end
