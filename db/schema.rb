# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_04_10_160000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer "priority", default: 0, null: false
    t.integer "attempts", default: 0, null: false
    t.text "handler", null: false
    t.text "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string "locked_by"
    t.string "queue"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["priority", "run_at"], name: "delayed_jobs_priority"
  end

  create_table "image_files", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "file_path", null: false
    t.string "file_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_id"], name: "index_image_files_on_job_id"
  end

  create_table "job_status_histories", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "old_status", null: false
    t.string "new_status", null: false
    t.bigint "initiator_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["initiator_id"], name: "index_job_status_histories_on_initiator_id"
    t.index ["job_id"], name: "index_job_status_histories_on_job_id"
  end

  create_table "jobs", force: :cascade do |t|
    t.bigint "client_id", null: false
    t.bigint "operator_id"
    t.integer "status", null: false
    t.string "title", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "custom_status"
    t.string "google_drive_folder_id"
    t.index ["client_id"], name: "index_jobs_on_client_id"
    t.index ["operator_id"], name: "index_jobs_on_operator_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "body", null: false
    t.boolean "is_read", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "reports", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "file_path", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_id"], name: "index_reports_on_job_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.string "session_id", null: false
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "cas_ticket"
    t.index ["cas_ticket"], name: "index_sessions_on_cas_ticket"
    t.index ["session_id"], name: "index_sessions_on_session_id", unique: true
    t.index ["updated_at"], name: "index_sessions_on_updated_at"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "username"
    t.string "uid"
    t.string "mail"
    t.string "ou"
    t.string "dn"
    t.string "sn"
    t.string "givenname"
    t.string "account_type"
    t.integer "role", default: 0, null: false
    t.index ["email"], name: "index_users_on_email"
    t.index ["username"], name: "index_users_on_username"
  end

  add_foreign_key "image_files", "jobs"
  add_foreign_key "job_status_histories", "jobs"
  add_foreign_key "job_status_histories", "users", column: "initiator_id"
  add_foreign_key "jobs", "users", column: "client_id"
  add_foreign_key "jobs", "users", column: "operator_id"
  add_foreign_key "notifications", "users"
  add_foreign_key "reports", "jobs"
end
