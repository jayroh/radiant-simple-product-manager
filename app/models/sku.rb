class Sku < ActiveRecord::Base
  belongs_to :product
  validates_presence_of :sku, :description, :price
  default_scope :order => "id DESC"
end
