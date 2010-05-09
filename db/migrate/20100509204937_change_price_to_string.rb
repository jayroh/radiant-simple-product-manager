class ChangePriceToString < ActiveRecord::Migration
  def self.up
    change_column :products, :price, :string
  end

  def self.down
    change_column :products, :price, :decimal
  end
end
