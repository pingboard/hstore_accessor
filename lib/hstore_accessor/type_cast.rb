module HstoreAccessor
  class TypeCast

    attr_reader :type

    def initialize(type)
      @type = type
      @rails = ::Hashie::Mash.new
      @rails[:major], @rails[:minor], @rails[:patch] = ::ActiveRecord.version.to_s.split('.').map(&:to_i)
    end

    def cast(value)
      return value unless ::ActiveRecord.present?

      case type
      when :string,:hash,:array  then value
      when :integer              then integer_cast value
      when :float                then value.to_f
      when :time                 then time_cast value
      when :date                 then date_cast value
      when :boolean              then boolean_cast value
      else value
      end
    end

    private

      def boolean_cast(value)
        case @rails.major
        # Rails 5
        when 5
          ActiveRecord::Type::Boolean.new.cast(value)
        # Rails 4
        when 4
          # Rails < 4.2
          if @rails.minor < 2
            ActiveRecord::ConnectionAdapters::Column.value_to_boolean(value)
          # Rails >= 4.2
          else
            ActiveRecord::Type::Boolean.new.type_cast_from_user(value)
          end
        # Other
        else
          value
        end
      end

      def date_cast(value)
        case @rails.major
        # Rails 5
        when 5
          ActiveRecord::Type::Date.new.cast(value)
        # Rails 4
        when 4
          # Rails < 4.2
          if @rails.minor < 2
            ActiveRecord::ConnectionAdapters::Column.value_to_date(value)
          # Rails >= 4.2
          else
            ActiveRecord::Type::Date.new.type_cast_from_user(value)
          end
        # Other
        else
          value
        end
      end

      def time_cast(value)
        case @rails.major
        # Rails 5
        when 5
          ActiveRecord::Type::DateTime.new.cast(value)
        # Rails 4
        when 4
          # Rails < 4.2
          if @rails.minor < 2
            string_to_time(value)
          # Rails >= 4.2
          else
            ActiveRecord::Type::DateTime.new.type_cast_from_user(value)
          end
        # Other
        else
          value
        end
      end

      # There is a bug in ActiveRecord::ConnectionAdapters::Column#string_to_time 
      # which drops the timezone. This has been fixed, but not released.
      # This method includes the fix. See: https://github.com/rails/rails/pull/12290
      def string_to_time string
        return string unless string.is_a?(String)
        return nil if string.empty?

        time_hash = Date._parse(string)
        time_hash[:sec_fraction] = ActiveRecord::ConnectionAdapters::Column.send(:microseconds, time_hash)
        (year, mon, mday, hour, min, sec, microsec, offset) = *time_hash.values_at(:year, :mon, :mday, :hour, :min, :sec, :sec_fraction, :offset)
        # Treat 0000-00-00 00:00:00 as nil.
        return nil if year.nil? || (year == 0 && mon == 0 && mday == 0)

        if offset
          time = Time.utc(year, mon, mday, hour, min, sec, microsec) rescue nil
          return nil unless time

          time -= offset
          ActiveRecord::Base.default_timezone == :utc ? time : time.getlocal
        else
          Time.public_send(ActiveRecord::Base.default_timezone, year, mon, mday, hour, min, sec, microsec) rescue nil
        end
      end

      def integer_cast(value)
        case @rails.major
        # Rails 5
        when 5
          ActiveRecord::Type::Integer.new.cast(value)
        # Rails 4
        when 4
          # Rails < 4.2
          if @rails.minor < 2
            ActiveRecord::ConnectionAdapters::Column.value_to_integer(value)
          # Rails >= 4.2
          else
            ActiveRecord::Type::Integer.new.type_cast_from_user(value)
          end
        # Other
        else
          value
        end
      end
  end
end