# frozen_string_literal: true

require_relative "query_helpers"
require "json"

module RailsPsqlJsonb
  module Querying
    extend ActiveSupport::Concern

    class_methods do
      def jsonb_where(column_name:, operator:, value:, force_value_type: nil, json_keys: [], exclude: false)
        ar_model = self.name.constantize
        db_column_name = RailsPsqlJsonb::QueryHelpers.db_column_name(ar_model, column_name)
        RailsPsqlJsonb::QueryHelpers.validate_column_name!(ar_model, db_column_name)
        RailsPsqlJsonb::QueryHelpers.validate_operator!(operator)

        query_operator = RailsPsqlJsonb::QueryHelpers::OPERATORS_MAP[operator]
        quoted_query_column_name = "#{RailsPsqlJsonb::QueryHelpers.quote_table_name(ar_model.table_name)}.#{RailsPsqlJsonb::QueryHelpers.quote_column_name(db_column_name)}"
        query_lhs = ([quoted_query_column_name] + json_keys.map { |string| RailsPsqlJsonb::QueryHelpers.quote(string) }).join(" -> ")
        query_rhs = RailsPsqlJsonb::QueryHelpers.quote(RailsPsqlJsonb::QueryHelpers.numeric_operator?(query_operator) ? value : value.to_json)
        query_cast_type =
          if !force_value_type.nil?
            force_value_type
          else
            if RailsPsqlJsonb::QueryHelpers.numeric_operator?(query_operator)
              "float"
            else
              "jsonb"
            end
          end

        query_clause = "(#{query_lhs})::#{query_cast_type} #{query_operator} (#{query_rhs})::#{query_cast_type}"
        exclude ? where.not(query_clause) : where(query_clause)
      end

      def jsonb_where_not(column_name:, operator:, value:, force_value_type: nil, json_keys: [])
        jsonb_where(column_name:, operator:, value:, force_value_type: force_value_type, json_keys: json_keys, exclude: true)
      end

      def jsonb_order(column_name:, json_keys:, direction:)
        ar_model = self.name.constantize
        db_column_name = RailsPsqlJsonb::QueryHelpers.db_column_name(ar_model, column_name)
        RailsPsqlJsonb::QueryHelpers.validate_column_name!(ar_model, db_column_name)
        RailsPsqlJsonb::QueryHelpers.validate_json_keys_for_ordering!(json_keys)
        RailsPsqlJsonb::QueryHelpers.validate_ordering!(direction)

        quoted_query_column_name = "#{RailsPsqlJsonb::QueryHelpers.quote_table_name(ar_model.table_name)}.#{RailsPsqlJsonb::QueryHelpers.quote_column_name(db_column_name)}"

        order(Arel.sql("(#{([quoted_query_column_name] + json_keys.map { |string| RailsPsqlJsonb::QueryHelpers.quote(string) }).join(" -> ")}) #{direction}"))
      end
    end
  end
end