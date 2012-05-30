require 'json'

module Rack
  class MultipartRelated
    autoload :VERSION, 'rack/multipart_related/version.rb'

    def initialize(app)
      @app = app
    end

    def call(env)
      req = Rack::Request.new(env)

      if req.media_type == 'multipart/related'
        start_part = trim_parameter_value(req.media_type_params['start'])
        start_part_type = trim_parameter_value(req.media_type_params['type'])

        if start_part_type == "application/json"
          start_part_attribute = get_attribute(req.params, start_part)
          json_data = ::JSON.parse(start_part_attribute[:tempfile].read)
          start_part_attribute[:tempfile].rewind
          env['START_CONTENT_TYPE'] ||= start_part_attribute[:type]

          new_params = handle_attributes__with_part_refs(json_data, req.params)
          env["rack.request.form_hash"] = new_params
        end
      end

      @app.call(env)
    end

    private
    def get_attribute(hash, attributes)
      attributes = attributes.scan(/[^\[\]]+/) if attributes.is_a?(String)
      attribute = attributes.shift
      value = attribute.nil? ? nil : hash[attribute]
      
      if value.is_a?(Hash) && ! attributes.empty?
        get_attribute(value, attributes)
      else
        value
      end
    end

    def handle_attributes__with_part_refs(data, original_params)

      if data.kind_of?(String)
        part_ref = data[/^cid:(.+)$/ni, 1]

        if part_ref
          data = get_attribute(original_params, part_ref)
        end
      elsif data.kind_of?(Array)
        data.each_with_index do |value, index|
          data[index] = handle_attributes__with_part_refs(value, original_params)
        end
      elsif data.kind_of?(Hash)
        data.each do |key, value|
          data[key] = handle_attributes__with_part_refs(value, original_params)
        end
      end

      data
    end

    def trim_parameter_value(raw)
      raw && raw.gsub(/^['"]/, '').gsub(/['"]$/, '')
    end
  end
end
