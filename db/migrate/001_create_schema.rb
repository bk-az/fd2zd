class CreateSchema < ActiveRecord::Migration[6.1]
  def change
    create_table :resources, if_not_exists: true do |t|
      t.bigint :fd_id
      t.string :type, index: true
      t.mediumtext :columns
      t.string :status, null: false, default: 'new'
      t.bigint :zd_id
      t.string :zd_error
    end

    add_index :resources, %i[type status]
    add_index :resources, %i[type fd_id], unique: true
  end
end
