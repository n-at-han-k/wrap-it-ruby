class CreateMenuItems < ActiveRecord::Migration[8.1]
  def change
    create_table :menu_items do |t|
      t.string :label, null: false
      t.string :icon
      t.string :route
      t.string :url
      t.string :item_type
      t.bigint :parent_id
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_foreign_key :menu_items, :menu_items, column: :parent_id
    add_index :menu_items, [ :parent_id, :position ]
  end
end
