class AddProductIdToSku < ActiveRecord::Migration
  def self.up
    add_column :skus, :product_id, :integer
  end

  def self.down
    remove_column :skus, :product_id
  end
end
