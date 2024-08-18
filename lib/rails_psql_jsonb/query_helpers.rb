# frozen_string_literal: true

require_relative "errors"
require_relative "quoting"
require "json"

module RailsPsqlJsonb
  module QueryHelpers
    OPERATORS_MAP = {
      :gt => ">",
      "gt" => ">",
      ">" => ">",
      :> => ">",
      :lt => "<",
      "lt" => "<",
      "<" => "<",
      :< => "<",
      :gte => ">=",
      "gte" => ">=",
      :>= => ">=",
      ">=" => ">=",
      :lte => "<=",
      "lte" => "<=",
      :<= => "<=",
      "<=" => "<=",
      :eq => "=",
      "eq" => "=",
      :"=" => "=",
      "=" => "=",
      :contains => "@>",
      "contains" => "@>",
      :"@>" =>"@>",
      "@>" =>"@>"
    }.freeze


    def self.numeric_operator?(query_operator)
      [">", "<", ">=", "<="].include?(query_operator)
    end

    def self.validate_operator!(operator)
      raise RailsPsqlJsonb::Errors::InvalidOperator.new(value: operator) if !OPERATORS_MAP.key?(operator)
    end

    def self.validate_column_name!(ar_model, column_name)
      raise RailsPsqlJsonb::Errors::InvalidColumnName.new(table_name: ar_model.table_name, column_name:) if !ar_model.column_names.include?(column_name.to_s) || ar_model.type_for_attribute(column_name).type != :jsonb
    end

    def self.validate_ordering!(value)
      raise RailsPsqlJsonb::Errors::InvalidOrder.new(value: value) if ![:asc, :desc, "asc", "desc"].include?(value)
    end

    def self.validate_json_keys_for_ordering!(json_keys)
      raise RailsPsqlJsonb::Errors::NoOrderKey unless json_keys.is_a?(Array) && !json_keys.empty?
    end

    def self.validate_atomic_update!(record, input)
      raise RailsPsqlJsonb::Errors::ActiveRecordError, "cannot update a new record" if record.new_record?
      raise RailsPsqlJsonb::Errors::ActiveRecordError, "cannot update a destroyed record" if record.destroyed?

      raise TypeError, "Atomic update input must be a hash" unless input.is_a?(Hash)

      input.each_key do |key|
        raise RailsPsqlJsonb::Errors::ReadOnlyAttribute(attribute: key) if record.class.readonly_attributes.include?(key.to_s)

        validate_column_name!(record.class, db_column_name(record.class, key))
      end
    end

    def self.db_column_name(ar_model, column_name)
      ar_model.attribute_alias?(column_name) ? ar_model.attribute_alias(column_name) : column_name
    end

    def self.quote(value)
      RailsPsqlJsonb::Quoting.quote(value)
    end

    def self.quote_column_name(value)
      RailsPsqlJsonb::Quoting.quote_column_name(value)
    end

    def self.quote_table_name(value)
      RailsPsqlJsonb::Quoting.quote_table_name(value)
    end

    def self.quote_jsonb_value(value)
      %('#{value.to_json}')
    end

    def self.quote_jsonb_keys(keys)
      "'{#{keys.map(&:to_s).join(',')}}'"
    end

    def self.concatenation(target, keys, value)
      "#{target}->#{keys.map { |x| quote(x) }.join('->')} || #{quote_jsonb_value(value)}"
    end
  end
end
