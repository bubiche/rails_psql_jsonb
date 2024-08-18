# frozen_string_literal: true

# Clone of activerecord's quoting implementation: https://github.com/rails/rails/blob/5bec50bc70380bb1e70e8fb0a1654130042b1f16/activerecord/lib/active_record/connection_adapters/postgresql/quoting.rb
# Use a module for this so we don't have to do use ActiveRecord::Base.connection.quote
# and require an active database connection even though the actual quoting implementation doesn't need it.

# A fix is available in activerecord 7.2 https://github.com/rails/rails/commit/0016280f4fde55d96738887093dc333aae0d107b
# => TODO: remove this module when supporting old activerecord versions is no longer needed.

module RailsPsqlJsonb
  module Quoting

    class IntegerOutOf64BitRange < StandardError
      def initialize(msg)
        super(msg)
      end
    end

    def self.quote_column_name(name)
      "\"#{name.to_s}\""
    end

    def self.quote_table_name(name)
      "\"#{name.to_s}\""
    end

    def self.check_int_in_range(value)
      if value.to_int > 9223372036854775807 || value.to_int < -9223372036854775808
        exception = <<~ERROR
          Provided value outside of the range of a signed 64bit integer.

          PostgreSQL will treat the column type in question as a numeric.
          This may result in a slow sequential scan due to a comparison
          being performed between an integer or bigint value and a numeric value.

          To allow for this potentially unwanted behavior, set
          ActiveRecord.raise_int_wider_than_64bit to false.
        ERROR
        raise IntegerOutOf64BitRange.new exception
      end
    end

    def self.quote(value) # :nodoc:
      if ActiveRecord.raise_int_wider_than_64bit && value.is_a?(Integer)
        check_int_in_range(value)
      end

      case value
      when Numeric
        if value.finite?
          value.to_s
        else
          "'#{value}'"
        end
      when Range
        quote(encode_range(value))
      when String, Symbol, ActiveSupport::Multibyte::Chars
        "'#{quote_string(value.to_s)}'"
      when true       then "TRUE"
      when false      then "FALSE"
      when nil        then "NULL"
      # BigDecimals need to be put in a non-normalized form and quoted.
      when BigDecimal then value.to_s("F")
      when Type::Time::Value then "'#{quoted_time(value)}'"
      when Date, Time then "'#{quoted_date(value)}'"
      when Class      then "'#{value}'"
      else raise TypeError, "can't quote #{value.class.name}"
      end
    end

    # Quotes strings for use in SQL input.
    def self.quote_string(s) # :nodoc:
      s.gsub("\\", '\&\&').gsub("'", "''")
    end

    def self.quote_table_name_for_assignment(table, attr)
      quote_column_name(attr)
    end

    # Quotes schema names for use in SQL queries.
    def self.quote_schema_name(schema_name)
      quote_column_name(schema_name)
    end

    def self.quoted_date(value) # :nodoc:
      if value.acts_like?(:time)
        if default_timezone == :utc
          value = value.getutc if !value.utc?
        else
          value = value.getlocal
        end
      end

      result = value.to_fs(:db)
      if value.respond_to?(:usec) && value.usec > 0
        result << "." << sprintf("%06d", value.usec)
      else
        result
      end
    end

    def self.type_cast(value) # :nodoc:
      case value
      when Type::Binary::Data
        # Return a bind param hash with format as binary.
        # See https://deveiate.org/code/pg/PG/Connection.html#method-i-exec_prepared-doc
        # for more information
        { value: value.to_s, format: 1 }
      when Range
        encode_range(value)
      when Rational
        value.to_f
      when Symbol, ActiveSupport::Multibyte::Chars
        value.to_s
      when true       then true
      when false      then false
      # BigDecimals need to be put in a non-normalized form and quoted.
      when BigDecimal then value.to_s("F")
      when nil, Numeric, String then value
      when Type::Time::Value then quoted_time(value)
      when Date, Time then quoted_date(value)
      else raise TypeError, "can't cast #{value.class.name}"
      end
    end

    def self.encode_array(array_data)
      encoder = array_data.encoder
      values = type_cast_array(array_data.values)

      result = encoder.encode(values)
      if encoding = determine_encoding_of_strings_in_array(values)
        result.force_encoding(encoding)
      end
      result
    end

    def self.encode_range(range)
      "[#{type_cast_range_value(range.begin)},#{type_cast_range_value(range.end)}#{range.exclude_end? ? ')' : ']'}"
    end

    def self.determine_encoding_of_strings_in_array(value)
      case value
      when ::Array then determine_encoding_of_strings_in_array(value.first)
      when ::String then value.encoding
      end
    end

    def self.type_cast_array(values)
      case values
      when ::Array then values.map { |item| type_cast_array(item) }
      else type_cast(values)
      end
    end

    def self.type_cast_range_value(value)
      infinity?(value) ? "" : type_cast(value)
    end

    def self.infinity?(value)
      value.respond_to?(:infinite?) && value.infinite?
    end
  end
end