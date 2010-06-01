class Sku < ActiveRecord::Base
  belongs_to :product
  validates_presence_of :sku, :description, :price
  
end
