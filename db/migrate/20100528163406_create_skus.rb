class CreateSkus < ActiveRecord::Migration
  def self.up
    create_table :skus do |t|
      t.string :sku
      t.text :description
      t.decimal :price,  :precision => 10, :scale => 2
      t.timestamps
    end
  end

  def self.down
    drop_table :skus
  end
end
