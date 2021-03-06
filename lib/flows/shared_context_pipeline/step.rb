module Flows
  class SharedContextPipeline
    EMPTY_ARRAY = [].freeze

    # @api private
    Step = Struct.new(:name, :body, :router_def, :next_step, keyword_init: true) do
      # :reek:ManualDispatch
      def initialize(name:, body: nil, **rest)
        if name.respond_to?(:call)
          body = name
          name = "#{body}+Step-Object-ID-#{object_id}"
        end

        super(name: name, body: body, **rest)
      end

      def to_node(pipeline_class)
        klass = self.class

        Flows::Flow::Node.new(
          body: body || pipeline_class.method(name),
          router: router_def.to_router(next_step),
          meta: { name: name },
          preprocessor: klass::NODE_PREPROCESSOR,
          postprocessor: klass::NODE_POSTPROCESSOR
        )
      end
    end

    Step.const_set(
      :NODE_PREPROCESSOR,
      lambda do |_input, context, node_meta|
        context[:class].before_each_callbacks.each do |callback|
          context[:instance].instance_exec(context[:class], node_meta[:name], context[:data], context[:meta], &callback)
        end

        [EMPTY_ARRAY, context[:data]]
      end
    )

    Step.const_set(
      :NODE_POSTPROCESSOR,
      lambda do |result, context, node_meta|
        context[:data].merge!(result.instance_variable_get(:@data))

        context[:class].after_each_callbacks.each do |callback|
          context[:instance]
            .instance_exec(context[:class], node_meta[:name], result, context[:data], context[:meta], &callback)
        end

        result
      end
    )
  end
end
