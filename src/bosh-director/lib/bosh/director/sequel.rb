Sequel.extension :blank

Sequel::Model.plugin :validation_helpers
Sequel::Model.raise_on_typecast_failure = false
Sequel::Model.require_valid_table = false

class Sequel::Model
  private

  def default_validation_helpers_options(type)
    case type
    when :exact_length, :integer, :format, :includes, :length_range,
      :max_length, :min_length, :not_null, :numeric, :type, :presence, :unique
      super.merge(message: type)
    else
      super
    end
  end
end
