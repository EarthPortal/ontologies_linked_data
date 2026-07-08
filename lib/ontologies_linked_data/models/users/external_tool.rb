module LinkedData::Models::Users
  class ExternalTool < LinkedData::Models::Base
    model :external_tool, name_with: lambda { |inst| uuid_uri_generator(inst) }
    attribute :toolName, enforce: [:existence]
    attribute :apikey, enforce: [:existence]
    attribute :user, inverse: { on: :user, attribute: :externalTools }
    embedded true
  end
end
