class AddCasTicketToSessions < ActiveRecord::Migration[8.0]
  def change
    add_column :sessions, :cas_ticket, :string
    add_index :sessions, :cas_ticket
  end
end
