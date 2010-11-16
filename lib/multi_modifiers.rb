# encoding: UTF-8
module MongoMapper
  module Plugins
    module Modifiers
      module ClassMethods
        def modify(*args, &blk)
          criteria = criteria_from_args(args)
          
          bulk_modifier = BulkModifier.new(self)
          bulk_modifier.instance_eval(&blk)
          
          # puts "Criteria: #{criteria.inspect}, modifiers: #{bulk_modifier.modifiers.inspect}"
          collection.update(criteria.to_hash, bulk_modifier.modifiers, :multi => true)
        end
        
        private
          def criteria_from_args(args)
            criteria_hash(args[0].is_a?(Hash) ? args[0] : {:id => args})
          end
      end
      
      module InstanceMethods
        def modify(&blk)
          self.class.modify(id, &blk)
        end
      end
      
      class BulkModifier
        attr_reader :doc_class, :modifiers
        
        def initialize(doc_class)
          @doc_class = doc_class
          @modifiers = {}
        end
        
        def increment(args)
          merge_modifier('$inc', args)
        end
        
        def decrement(keys)
          values, to_decrement = keys.values, {}
          keys.keys.each_with_index { |k, i| to_decrement[k] = -values[i].abs }
          merge_modifier('$inc', to_decrement)
        end

        def set(updates)
          updates.each do |key, value|
            updates[key] = doc_class.keys[key].set(value) if doc_class.key?(key)
          end
          merge_modifier('$set', updates)
        end

        def unset(*keys)
          modifiers = keys.inject({}) { |hash, key| hash[key] = 1; hash }
          merge_modifier('$unset', modifiers)
        end

        def push(updates)
          merge_modifier('$push', updates)
        end
        
        def push_all(updates)
          merge_modifier('$pushAll', updates)
        end
        
        def add_to_set(updates)
          merge_modifier('$addToSet', updates)
        end
        alias push_uniq add_to_set
        
        def pull(updates)
          merge_modifier('$pull', updates)
        end
        
        def pull_all(updates)
          merge_modifier('$pullAll', updates)
        end
        
        def pop(updates)
          merge_modifier('$pop', updates)
        end

        private
          def merge_modifier(key, value)
            @modifiers[key] ||= {}
            @modifiers[key] = @modifiers[key].merge(value)
          end
      end
    end
  end
end