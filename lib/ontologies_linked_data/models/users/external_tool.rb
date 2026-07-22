module LinkedData::Models::Users
  class ExternalTool < LinkedData::Models::Base
    model :user_external_tool, name_with: lambda { |inst| uuid_uri_generator(inst) }
    attribute :toolName, enforce: [:existence]
    attribute :apikey, enforce: [:existence]
    attribute :user, inverse: {on: :user, attribute: :externalTools}
    embedded true

    attr_accessor :show_apikey
    serialize_never :show_apikey
    serialize_filter lambda {|inst| show_apikey?(inst)}

    def self.show_apikey?(inst)
      if inst.show_apikey
        attributes
      else
        attributes - [:apikey]
      end
    end
  end
end
