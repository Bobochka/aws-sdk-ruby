module Aws
  module Query
    class Handler < Seahorse::Client::Handler

      include Seahorse::Model::Shapes

      CONTENT_TYPE = 'application/x-www-form-urlencoded; charset=utf-8'

      METADATA_REF = begin
        request_id = ShapeRef.new(
          shape: StringShape.new,
          location_name: 'RequestId')
        response_metadata = StructureShape.new
        response_metadata.add_member(:request_id, request_id)
        ShapeRef.new(shape: response_metadata, location_name: 'ResponseMetadata')
      end

      # @param [Seahorse::Client::RequestContext] context
      # @return [Seahorse::Client::Response]
      def call(context)
        build_request(context)
        @handler.call(context).on_success do |response|
          response.error = nil
          response.data = parse_xml(context)
        end
      end

      private

      def build_request(context)
        context.http_request.headers['Content-Type'] = CONTENT_TYPE
        param_list = ParamList.new
        param_list.set('Version', context.config.api.version)
        param_list.set('Action', context.operation.name)
        if input_shape = context.operation.input
          apply_params(param_list, context.params, input_shape)
        end
        context.http_request.body = param_list.to_io
      end

      def apply_params(param_list, params, rules)
        ParamBuilder.new(param_list).apply(rules, params)
      end

      def parse_xml(context)
        if context.operation.output
          data = Xml::Parser.new(rules(context)).parse(xml(context))
          remove_wrapper(data, context)
        else
          EmptyStructure.new
        end
      end

      def xml(context)
        context.http_response.body_contents
      end

      def rules(context)
        shape = Seahorse::Model::Shapes::StructureShape.new
        shape.add_member(:result, ShapeRef.new(
          shape: context.operation.output.shape,
          location_name: context.operation.name + 'Result'
        ))
        shape.add_member(:response_metadata, METADATA_REF)
        ShapeRef.new(shape: shape)
      end

      def remove_wrapper(data, context)
        if context.operation.output['resultWrapper']
          context[:request_id] = data.response_metadata.request_id
          data.result || Structure.new(context.operation.output.shape.member_names)
        else
          data
        end
      end

    end
  end
end
