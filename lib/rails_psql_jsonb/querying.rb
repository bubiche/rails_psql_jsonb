# frozen_string_literal: true

require_relative "query_helpers"
require "json"

module RailsPsqlJsonb
  module Querying
    extend ActiveSupport::Concern

    class_methods do
      def jsonb_where(column_name:, operator:, value:, force_value_type: nil, json_keys: [], exclude: false)
        _resolved, quoted_column = resolve_jsonb_column(column_name)
        RailsPsqlJsonb::QueryHelpers.validate_operator!(operator)

        query_operator = RailsPsqlJsonb::QueryHelpers::OPERATORS_MAP[operator]

        if RailsPsqlJsonb::QueryHelpers.existence_operator?(query_operator)
          query_clause = build_existence_clause(quoted_column, query_operator, value, json_keys)
          return exclude ? where.not(query_clause) : where(query_clause)
        end

        is_numeric = RailsPsqlJsonb::QueryHelpers.numeric_operator?(query_operator)
        # Use text-extraction operators (->> / #>>) for numeric comparisons when json_keys
        # are present: extracts as text then casts to float, which is the idiomatic PG approach.
        use_text_extraction = is_numeric && force_value_type.nil? && !json_keys.empty?

        lhs_raw = build_lhs_expression(quoted_column, json_keys, text_extraction: use_text_extraction)

        query_clause = if use_text_extraction
          "(#{lhs_raw})::float #{query_operator} #{RailsPsqlJsonb::QueryHelpers.quote(value)}"
        else
          query_rhs = RailsPsqlJsonb::QueryHelpers.quote(is_numeric ? value : value.to_json)
          cast_type = force_value_type || (is_numeric ? "float" : "jsonb")
          "(#{lhs_raw})::#{cast_type} #{query_operator} (#{query_rhs})::#{cast_type}"
        end

        exclude ? where.not(query_clause) : where(query_clause)
      end

      def jsonb_where_not(column_name:, operator:, value:, force_value_type: nil, json_keys: [])
        jsonb_where(column_name:, operator:, value:, force_value_type:, json_keys:, exclude: true)
      end

      def jsonb_order(column_name:, json_keys:, direction:)
        _resolved, quoted_column = resolve_jsonb_column(column_name)
        RailsPsqlJsonb::QueryHelpers.validate_json_keys_for_ordering!(json_keys)
        RailsPsqlJsonb::QueryHelpers.validate_ordering!(direction)

        lhs = build_lhs_expression(quoted_column, json_keys)
        nulls_clause = direction.to_s.downcase == "asc" ? "NULLS LAST" : "NULLS FIRST"
        order(Arel.sql("(#{lhs}) #{direction} #{nulls_clause}"))
      end

      def jsonb_where_exists(column_name:, key:, json_keys: [], exclude: false)
        jsonb_where(column_name:, operator: :exists, value: key, json_keys:, exclude:)
      end

      def jsonb_where_exists_any(column_name:, keys:, json_keys: [], exclude: false)
        jsonb_where(column_name:, operator: :exists_any, value: keys, json_keys:, exclude:)
      end

      def jsonb_where_exists_all(column_name:, keys:, json_keys: [], exclude: false)
        jsonb_where(column_name:, operator: :exists_all, value: keys, json_keys:, exclude:)
      end

      # Returns the SQL to create a GIN index on a JSONB column for use in a migration:
      #   execute MyModel.jsonb_gin_index_sql(column_name: "props")
      #
      # using: :jsonb_path_ops — smaller index, faster for @> (contains) queries
      # using: :jsonb_ops      — default GIN, also supports ?, ?|, ?& key-existence operators
      def jsonb_gin_index_sql(column_name:, using: :jsonb_path_ops)
        table = connection.quote_table_name(table_name)
        col   = connection.quote_column_name(column_name.to_s)
        "CREATE INDEX ON #{table} USING GIN (#{col} #{using});"
      end

      def jsonb_batch_update(records_and_payloads)
        transaction do
          records_and_payloads.each do |record, input|
            record.jsonb_update!(input)
          end
        end
      end

      private

      def resolve_jsonb_column(column_name)
        resolved = RailsPsqlJsonb::QueryHelpers.db_column_name(self, column_name)
        RailsPsqlJsonb::QueryHelpers.validate_column_name!(self, resolved)
        quoted = "#{RailsPsqlJsonb::QueryHelpers.quote_table_name(table_name)}.#{RailsPsqlJsonb::QueryHelpers.quote_column_name(resolved)}"
        [resolved, quoted]
      end

      # Builds the LHS SQL expression for a JSONB path.
      # For multi-key paths uses #> / #>> (path operators) instead of chained ->.
      # text_extraction: true uses ->> / #>> (returns text, used before numeric cast).
      def build_lhs_expression(quoted_column, json_keys, text_extraction: false)
        return quoted_column if json_keys.empty?
        if json_keys.length == 1
          op = text_extraction ? "->>" : "->"
          "#{quoted_column} #{op} #{RailsPsqlJsonb::QueryHelpers.quote(json_keys.first.to_s)}"
        else
          path = json_keys.map(&:to_s).join(",")
          op = text_extraction ? "#>>" : "#>"
          "#{quoted_column} #{op} '{#{path}}'"
        end
      end

      def build_existence_clause(quoted_column, operator, value, json_keys)
        case operator
        when "?"
          unless value.is_a?(String) || value.is_a?(Symbol)
            raise TypeError, "value for ? (exists) operator must be a String or Symbol, got #{value.class}"
          end
        when "?|", "?&"
          raise TypeError, "value for #{operator} operator must be an Array, got #{value.class}" unless value.is_a?(Array)
        end

        lhs = build_lhs_expression(quoted_column, json_keys)

        case operator
        when "?"
          "#{lhs} ? #{RailsPsqlJsonb::QueryHelpers.quote(value.to_s)}"
        when "?|", "?&"
          keys = Array(value).map { |k| RailsPsqlJsonb::QueryHelpers.quote(k.to_s) }.join(", ")
          "#{lhs} #{operator} ARRAY[#{keys}]"
        end
      end
    end
  end
end
