class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  # Primary keys are random UUIDs, so order by creation time when no order is given (e.g. .first/.last).
  self.implicit_order_column = "created_at"
end
