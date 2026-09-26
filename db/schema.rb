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

ActiveRecord::Schema[8.1].define(version: 2026_09_25_013702) do
  create_table "geneva_drive_step_executions", force: :cascade do |t|
    t.datetime "canceled_at"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "error_backtrace"
    t.string "error_class_name"
    t.text "error_message"
    t.datetime "failed_at"
    t.datetime "finished_at"
    t.string "job_id"
    t.text "metadata"
    t.string "outcome"
    t.datetime "scheduled_for", null: false
    t.datetime "skipped_at"
    t.datetime "started_at"
    t.string "state", default: "scheduled", null: false
    t.string "step_name", null: false
    t.datetime "updated_at", null: false
    t.integer "workflow_id", null: false
    t.json "cursor"
    t.bigint "continues_from_id"
    t.index ["continues_from_id"], name: "index_geneva_drive_step_executions_on_continues_from_id"
    t.index ["finished_at"], name: "index_geneva_drive_step_executions_on_finished_at"
    t.index ["scheduled_for"], name: "index_geneva_drive_step_executions_on_scheduled_for"
    t.index ["started_at"], name: "index_geneva_drive_step_executions_in_progress_started_at", where: "state = 'in_progress'"
    t.index ["state", "scheduled_for"], name: "index_geneva_drive_step_executions_scheduled"
    t.index ["state"], name: "index_geneva_drive_step_executions_on_state"
    t.index ["workflow_id", "created_at"], name: "idx_on_workflow_id_created_at_af16a14fb2"
    t.index ["workflow_id", "state"], name: "index_geneva_drive_step_executions_on_workflow_id_and_state"
    t.index ["workflow_id"], name: "index_geneva_drive_step_executions_on_workflow_id"
    t.index ["workflow_id"], name: "index_geneva_drive_step_executions_one_active", unique: true, where: "state IN ('scheduled', 'in_progress')"
  end

  create_table "geneva_drive_workflows", force: :cascade do |t|
    t.boolean "allow_multiple", default: false, null: false
    t.datetime "created_at", null: false
    t.string "current_step_name"
    t.integer "hero_id"
    t.string "hero_type"
    t.string "next_step_name"
    t.datetime "started_at"
    t.string "state", default: "ready", null: false
    t.datetime "transitioned_at"
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.text "metadata"
    t.index ["hero_type", "hero_id"], name: "index_geneva_drive_workflows_on_hero_type_and_hero_id"
    t.index ["state"], name: "index_geneva_drive_workflows_on_state"
    t.index ["type", "hero_type", "hero_id"], name: "index_geneva_drive_workflows_unique_ongoing", unique: true, where: "state NOT IN ('finished', 'canceled') AND allow_multiple = 0"
    t.index ["type"], name: "index_geneva_drive_workflows_on_type"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "geneva_drive_step_executions", "geneva_drive_workflows", column: "workflow_id", on_delete: :cascade
  add_foreign_key "sessions", "users"
end
