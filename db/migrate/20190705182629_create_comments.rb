class CreateComments < ActiveRecord::Migration[5.2]
  def change
    create_table :comments do |t|
      t.text :comment_content
      t.string :commenter_id
      t.integer :post_id
      t.datetime :created_at
    end
  end
end
