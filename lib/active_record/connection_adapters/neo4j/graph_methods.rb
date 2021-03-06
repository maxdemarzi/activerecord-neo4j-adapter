module ActiveRecord
  module ConnectionAdapters
    module Neo4j
      module GraphMethods
        
        def self.included(base)
          base.extend ClassMethods
          base.send :include, InstanceMethods
        end # included

        module ClassMethods
          def load_from_graph(records)
            raise GraphMethodsNotSupportedError.new("Graph methods are not supported on #{self.to_s}") if not supports_graph_methods?

            records = Array.wrap records
            records.map do |record|
              # Get node id from graph record
              node_id = record['self'].split('/').last.to_i
              # Get model node connected to this node
              model_node = connection.execute_gremlin("g.v(node_id).in('instances').next()", "GraphMethods", :node_id => node_id)

              if not (model_node && model_node['data'] && model_node['data']['model'])
                model = record['data']['model'].constantize
                # Find the corresponding record in database
                instance = model.find(record['data']['model_id'])
              else
                # Get relevant model from model node
                model = (model_node['data']['class_name'] || model_node['data']['model']).classify.constantize
                # Add node_id to record
                record['data']['id'] = node_id
                # Instantiate an object
                instance = model.allocate
                instance.init_with('attributes' => record['data'])
              end

              instance
            end
          end # instantiate_from_graph

          def supports_graph_methods?
            return connection.respond_to? :execute_gremlin
          end
        end # ClassMethods

        module InstanceMethods
        end # InstanceMethods

      end # GraphMethods

      class GraphMethodsNotSupportedError < ::StandardError
      end
    end # Neo4j
  end # ConnectionAdapters
end # ActiveRecord

ActiveRecord::Base.send :include, ActiveRecord::ConnectionAdapters::Neo4j::GraphMethods