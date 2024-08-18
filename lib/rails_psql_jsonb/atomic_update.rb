# frozen_string_literal: true

# Inspired by https://github.com/antoinemacia/atomic_json

require_relative "query_helpers"

module RailsPsqlJsonb
  module AtomicUpdate
    extend ActiveSupport::Concern

    def jsonb_update(input)
      update_query = build_update_query(input.deep_dup, touch: true)
      run_callbacks(:save) do
        self.class.connection.exec_update(update_query)
        reload.validate
      end
    end

    def jsonb_update!(input)
      update_query = build_update_query(input, touch: true)
      puts "HELLO #{update_query}"
      run_callbacks(:save) do
        self.class.connection.exec_update(update_query)
        reload.validate!
      end
    end

    def jsonb_update_columns(input)
      update_query = build_update_query(input, touch: false)
      self.class.connection.exec_update(update_query)
    end

    def build_update_query(input, touch: false)
      RailsPsqlJsonb::QueryHelpers.validate_atomic_update!(self, input)

      <<~SQL
        UPDATE #{RailsPsqlJsonb::QueryHelpers.quote_table_name(self.class.table_name)}
        SET #{build_set_subquery(input, touch)}
        WHERE id = #{RailsPsqlJsonb::QueryHelpers.quote(self.id)};
      SQL
    end

    def build_set_subquery(attributes, touch)
      updates = json_updates_agg(attributes)
      updates << timestamp_update_string if touch && self.has_attribute?(:updated_at)
      updates.join(',')
    end

    def json_updates_agg(attributes)
      attributes.map do |column, payload|
        "#{RailsPsqlJsonb::QueryHelpers.quote_column_name(column)} = #{json_deep_merge(column, payload)}"
      end
    end

    def timestamp_update_string
      "#{RailsPsqlJsonb::QueryHelpers.quote_column_name(:updated_at)} = #{RailsPsqlJsonb::QueryHelpers.quote(Time.now)}"
    end

    def json_deep_merge(target, payload)
      loop do
        keys, value = traverse_payload(Hash[*payload.shift])
        target = jsonb_set_query_string(target, keys, value)
        break target if payload.empty?
      end
    end

    ##
    # Traverse the Hash payload, incrementally
    # aggregating all hash keys into an array
    # and use the last child as value
    def traverse_payload(key_value_pair, keys = [])
      loop do
        key, val = key_value_pair.flatten
        keys << key.to_s
        break [keys, val] unless single_value_hash?(val)
        key_value_pair = val
      end
    end

    def jsonb_set_query_string(target, keys, value)
      <<~EOF
        jsonb_set(
          #{target}::jsonb,
          #{RailsPsqlJsonb::QueryHelpers.quote_jsonb_keys(keys)},
          #{multi_value_hash?(value) ? RailsPsqlJsonb::QueryHelpers.concatenation(target, keys, value) : RailsPsqlJsonb::QueryHelpers.quote_jsonb_value(value)}
        )::jsonb
      EOF
    end

    def multi_value_hash?(value)
      value.is_a?(Hash) && value.keys.count > 1
    end

    def single_value_hash?(value)
      value.is_a?(Hash) && value.keys.count == 1
    end
  end
end
