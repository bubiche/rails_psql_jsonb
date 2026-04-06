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
      update_query = build_update_query(input.deep_dup, touch: true)
      run_callbacks(:save) do
        self.class.connection.exec_update(update_query)
        reload.validate!
      end
    end

    def jsonb_update_columns(input)
      update_query = build_update_query(input.deep_dup, touch: false)
      self.class.connection.exec_update(update_query)
    end

    # Atomically removes a key (or nested key path) from a JSONB column.
    # Uses PostgreSQL's #- operator which is safe when the path doesn't exist.
    #
    # Examples:
    #   record.jsonb_delete_key("props", "age")             # removes props['age']
    #   record.jsonb_delete_key("props", "nested", "inner") # removes props['nested']['inner']
    def jsonb_delete_key(column_name, *key_path)
      validate_key_path!(key_path)
      col = validate_record_and_column!(column_name)
      exec_delete_key(col, key_path, touch: true)
      reload
    end

    def jsonb_delete_key!(column_name, *key_path)
      jsonb_delete_key(column_name, *key_path)
      validate!
      self
    end

    def jsonb_delete_key_columns(column_name, *key_path)
      validate_key_path!(key_path)
      col = validate_record_and_column!(column_name)
      exec_delete_key(col, key_path, touch: false)
      reload
    end

    # Atomically appends a value to a JSONB array at the given key path.
    # Initializes to [value] if the key doesn't exist yet.
    #
    # Example:
    #   record.jsonb_array_append("props", ["tags"], "ruby")
    def jsonb_array_append(column_name, key_path, value)
      col      = validate_record_and_column!(column_name)
      key_path = Array(key_path)
      validate_key_path!(key_path)

      pg_path    = "{#{key_path.map(&:to_s).join(",")}}"
      quoted_col = RailsPsqlJsonb::QueryHelpers.quote_column_name(col)
      quoted_tbl = RailsPsqlJsonb::QueryHelpers.quote_table_name(self.class.table_name)
      quoted_val = RailsPsqlJsonb::QueryHelpers.quote(value.to_json)

      sql = <<~SQL
        UPDATE #{quoted_tbl}
        SET #{quoted_col} = jsonb_set(
          #{quoted_col}::jsonb,
          '#{pg_path}',
          COALESCE(#{quoted_col} #> '#{pg_path}', '[]'::jsonb) || jsonb_build_array(#{quoted_val}::jsonb)
        )#{optional_touch_sql}
        WHERE id = #{RailsPsqlJsonb::QueryHelpers.quote(id)};
      SQL
      self.class.connection.exec_update(sql)
      reload
    end

    # Atomically removes all occurrences of value from a JSONB array at the given key path.
    # Returns [] if all elements are removed or the key doesn't exist.
    #
    # Example:
    #   record.jsonb_array_remove("props", ["tags"], "ruby")
    def jsonb_array_remove(column_name, key_path, value)
      col      = validate_record_and_column!(column_name)
      key_path = Array(key_path)
      validate_key_path!(key_path)

      pg_path    = "{#{key_path.map(&:to_s).join(",")}}"
      quoted_col = RailsPsqlJsonb::QueryHelpers.quote_column_name(col)
      quoted_tbl = RailsPsqlJsonb::QueryHelpers.quote_table_name(self.class.table_name)
      quoted_val = RailsPsqlJsonb::QueryHelpers.quote(value.to_json)

      sql = <<~SQL
        UPDATE #{quoted_tbl}
        SET #{quoted_col} = jsonb_set(
          #{quoted_col}::jsonb,
          '#{pg_path}',
          COALESCE(
            (SELECT jsonb_agg(e)
             FROM jsonb_array_elements(#{quoted_col} #> '#{pg_path}') AS e
             WHERE e <> #{quoted_val}::jsonb),
            '[]'::jsonb
          )
        )#{optional_touch_sql}
        WHERE id = #{RailsPsqlJsonb::QueryHelpers.quote(id)};
      SQL
      self.class.connection.exec_update(sql)
      reload
    end

    # Atomically increments (or decrements with negative delta) a numeric JSONB value.
    # Initializes missing keys to 0 before applying the delta.
    #
    # Example:
    #   record.jsonb_increment("props", ["score"], 5)
    #   record.jsonb_increment("props", ["score"], -1)  # decrement
    def jsonb_increment(column_name, key_path, delta = 1)
      raise TypeError, "delta must be Numeric, got #{delta.class}" unless delta.is_a?(Numeric)
      col      = validate_record_and_column!(column_name)
      key_path = Array(key_path)
      validate_key_path!(key_path)

      pg_path    = "{#{key_path.map(&:to_s).join(",")}}"
      quoted_col = RailsPsqlJsonb::QueryHelpers.quote_column_name(col)
      quoted_tbl = RailsPsqlJsonb::QueryHelpers.quote_table_name(self.class.table_name)

      sql = <<~SQL
        UPDATE #{quoted_tbl}
        SET #{quoted_col} = jsonb_set(
          #{quoted_col}::jsonb,
          '#{pg_path}',
          to_jsonb(COALESCE((#{quoted_col} #>> '#{pg_path}')::numeric, 0) + #{RailsPsqlJsonb::QueryHelpers.quote(delta)})
        )#{optional_touch_sql}
        WHERE id = #{RailsPsqlJsonb::QueryHelpers.quote(id)};
      SQL
      self.class.connection.exec_update(sql)
      reload
    end

    private

    def validate_key_path!(key_path)
      raise ArgumentError, "key_path must not be empty" if key_path.empty?
    end

    # Returns ", updated_at = '...'" when the model has an updated_at column, else "".
    # Pass touch: false to suppress the timestamp even when the column exists.
    def optional_touch_sql(touch: true)
      return "" unless touch && has_attribute?(:updated_at)
      ", #{timestamp_update_string}"
    end

    # Validates that the record is persisted and the column is a JSONB column.
    # Returns the resolved (alias-expanded) column name.
    def validate_record_and_column!(column_name)
      raise RailsPsqlJsonb::Errors::ActiveRecordError, "cannot update a new record" if new_record?
      raise RailsPsqlJsonb::Errors::ActiveRecordError, "cannot update a destroyed record" if destroyed?
      col = RailsPsqlJsonb::QueryHelpers.db_column_name(self.class, column_name.to_s)
      RailsPsqlJsonb::QueryHelpers.validate_column_name!(self.class, col)
      col
    end

    def exec_delete_key(col, key_path, touch:)
      quoted_col = RailsPsqlJsonb::QueryHelpers.quote_column_name(col)
      quoted_tbl = RailsPsqlJsonb::QueryHelpers.quote_table_name(self.class.table_name)
      path_array = key_path.map { |k| RailsPsqlJsonb::QueryHelpers.quote(k.to_s) }.join(", ")
      sql = "UPDATE #{quoted_tbl} SET #{quoted_col} = #{quoted_col} #- ARRAY[#{path_array}]#{optional_touch_sql(touch: touch)} WHERE id = #{RailsPsqlJsonb::QueryHelpers.quote(id)};"
      self.class.connection.exec_update(sql)
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
      updates << timestamp_update_string if touch && has_attribute?(:updated_at)
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

    # Returns [key_path, leaf_value] by walking nested single-key hashes.
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
