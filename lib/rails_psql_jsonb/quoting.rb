# frozen_string_literal: true

# Minimal copy of ActiveRecord's PostgreSQL quoting module.
# Clone of: https://github.com/rails/rails/blob/5bec50bc70380bb1e70e8fb0a1654130042b1f16/activerecord/lib/active_record/connection_adapters/postgresql/quoting.rb
#
# Used as a module so we don't need ActiveRecord::Base.connection.quote, which
# requires an active database connection even though quoting itself doesn't need one.
#
# A fix is available in ActiveRecord 7.2:
# https://github.com/rails/rails/commit/0016280f4fde55d96738887093dc333aae0d107b
# TODO: remove this module when minimum supported ActiveRecord version is >= 7.2.

module RailsPsqlJsonb
  module Quoting

    class IntegerOutOf64BitRange < StandardError
      def initialize(msg)
        super(msg)
      end
    end

    def self.quote_column_name(name)
      "\"#{name}\""
    end

    def self.quote_table_name(name)
      "\"#{name}\""
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

    def self.quote(value)
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
      when BigDecimal then value.to_s("F")
      when Date, Time then "'#{quoted_date(value)}'"
      when Class      then "'#{value}'"
      else raise TypeError, "can't quote #{value.class.name}"
      end
    end

    def self.quote_string(s)
      s.gsub("\\", '\&\&').gsub("'", "''")
    end

    def self.quoted_date(value)
      if value.acts_like?(:time)
        if ActiveRecord.default_timezone == :utc
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

    def self.encode_range(range)
      "[#{type_cast_range_value(range.begin)},#{type_cast_range_value(range.end)}#{range.exclude_end? ? ')' : ']'}"
    end

    def self.type_cast_range_value(value)
      return "" if infinity?(value)
      case value
      when Rational then value.to_f
      when Symbol, ActiveSupport::Multibyte::Chars then value.to_s
      when true  then true
      when false then false
      when BigDecimal then value.to_s("F")
      when nil, Numeric, String then value
      when Date, Time then quoted_date(value)
      else raise TypeError, "can't cast #{value.class.name}"
      end
    end

    def self.infinity?(value)
      value.respond_to?(:infinite?) && value.infinite?
    end
  end
end
