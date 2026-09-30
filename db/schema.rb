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

ActiveRecord::Schema[8.1].define(version: 2026_09_30_120000) do
  create_table "ai_models", force: :cascade do |t|
    t.string "slug", null: false
    t.string "name", null: false
    t.string "maker"
    t.integer "hue", default: 220, null: false
    t.string "monogram", null: false
    t.string "status", default: "approved", null: false
    t.json "category_slugs", default: [], null: false
    t.integer "created_by_id"
    t.integer "position", default: 0, null: false
    t.string "family"
    t.date "released_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "admin_edited_at"
    t.string "mark"
    t.string "vibe_check_url"
    t.index ["created_by_id"], name: "index_ai_models_on_created_by_id"
    t.index ["slug"], name: "index_ai_models_on_slug", unique: true
    t.index ["status"], name: "index_ai_models_on_status"
  end

  create_table "categories", force: :cascade do |t|
    t.string "slug", null: false
    t.string "name", null: false
    t.string "blurb"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_categories_on_slug", unique: true
  end

  create_table "entries", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "category_id", null: false
    t.integer "tool_id", null: false
    t.integer "ai_model_id"
    t.integer "rank", null: false
    t.string "context"
    t.string "effort"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ai_model_id"], name: "index_entries_on_ai_model_id"
    t.index ["category_id"], name: "index_entries_on_category_id"
    t.index ["tool_id"], name: "index_entries_on_tool_id"
    t.index ["user_id", "category_id", "rank"], name: "index_entries_on_user_id_and_category_id_and_rank", unique: true
    t.index ["user_id", "category_id", "tool_id"], name: "index_entries_on_user_id_and_category_id_and_tool_id", unique: true
  end

  create_table "entry_changes", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "category_id", null: false
    t.integer "tool_id", null: false
    t.integer "ai_model_id"
    t.string "action", null: false
    t.string "source", null: false
    t.string "client_name"
    t.json "details", default: {}, null: false
    t.datetime "created_at", null: false
    t.integer "rank"
    t.integer "from_rank"
    t.string "context"
    t.string "effort"
    t.index ["ai_model_id"], name: "index_entry_changes_on_ai_model_id"
    t.index ["category_id", "user_id", "created_at"], name: "index_entry_changes_for_replay"
    t.index ["category_id"], name: "index_entry_changes_on_category_id"
    t.index ["tool_id"], name: "index_entry_changes_on_tool_id"
    t.index ["user_id", "created_at"], name: "index_entry_changes_on_user_id_and_created_at"
    t.index ["user_id"], name: "index_entry_changes_on_user_id"
  end

  create_table "flipper_features", force: :cascade do |t|
    t.string "key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_flipper_features_on_key", unique: true
  end

  create_table "flipper_gates", force: :cascade do |t|
    t.string "feature_key", null: false
    t.string "key", null: false
    t.text "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["feature_key", "key", "value"], name: "index_flipper_gates_on_feature_key_and_key_and_value", unique: true
  end

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

  create_table "oauth_authorization_codes", force: :cascade do |t|
    t.string "code_digest", null: false
    t.integer "oauth_client_id", null: false
    t.integer "user_id", null: false
    t.integer "oauth_grant_id"
    t.string "redirect_uri", null: false
    t.string "code_challenge", null: false
    t.string "resource", null: false
    t.string "scope", null: false
    t.datetime "expires_at", null: false
    t.datetime "used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code_digest"], name: "index_oauth_authorization_codes_on_code_digest", unique: true
    t.index ["oauth_client_id"], name: "index_oauth_authorization_codes_on_oauth_client_id"
    t.index ["oauth_grant_id"], name: "index_oauth_authorization_codes_on_oauth_grant_id"
    t.index ["user_id"], name: "index_oauth_authorization_codes_on_user_id"
  end

  create_table "oauth_clients", force: :cascade do |t|
    t.string "client_id", null: false
    t.string "client_name", null: false
    t.json "redirect_uris", default: [], null: false
    t.string "software_id"
    t.string "software_version"
    t.string "client_uri"
    t.string "logo_uri"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_oauth_clients_on_client_id", unique: true
  end

  create_table "oauth_grants", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "oauth_client_id", null: false
    t.string "resource", null: false
    t.string "scope", null: false
    t.string "access_digest", null: false
    t.datetime "access_expires_at", null: false
    t.string "refresh_digest", null: false
    t.datetime "refresh_expires_at", null: false
    t.string "previous_refresh_digest"
    t.datetime "revoked_at"
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["access_digest"], name: "index_oauth_grants_on_access_digest", unique: true
    t.index ["oauth_client_id"], name: "index_oauth_grants_on_oauth_client_id"
    t.index ["previous_refresh_digest"], name: "index_oauth_grants_on_previous_refresh_digest"
    t.index ["refresh_digest"], name: "index_oauth_grants_on_refresh_digest", unique: true
    t.index ["user_id"], name: "index_oauth_grants_on_user_id"
  end

  create_table "pick_suggestions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "category_id", null: false
    t.integer "tool_id", null: false
    t.integer "ai_model_id"
    t.string "context"
    t.string "effort"
    t.integer "slot_hint"
    t.integer "replaces_rank"
    t.integer "replaces_tool_id"
    t.integer "replaces_ai_model_id"
    t.integer "oauth_client_id"
    t.string "client_name"
    t.string "status", default: "open", null: false
    t.datetime "resolved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ai_model_id"], name: "index_pick_suggestions_on_ai_model_id"
    t.index ["tool_id"], name: "index_pick_suggestions_on_tool_id"
    t.index ["user_id", "category_id", "status"], name: "index_pick_suggestions_on_user_id_and_category_id_and_status"
    t.index ["user_id", "oauth_client_id", "status"], name: "index_pick_suggestions_on_client"
    t.check_constraint "context IS NULL OR context IN ('200k', '1m')", name: "pick_suggestions_context_check"
    t.check_constraint "effort IS NULL OR effort IN ('low', 'medium', 'high')", name: "pick_suggestions_effort_check"
    t.check_constraint "status IN ('open', 'confirmed', 'dismissed', 'withdrawn', 'superseded', 'expired')", name: "pick_suggestions_status_check"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "tools", force: :cascade do |t|
    t.string "slug", null: false
    t.string "name", null: false
    t.string "maker"
    t.integer "hue", default: 220, null: false
    t.string "monogram", null: false
    t.string "status", default: "approved", null: false
    t.json "category_slugs", default: [], null: false
    t.integer "created_by_id"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "admin_edited_at"
    t.string "mark"
    t.json "paired_models", default: [], null: false
    t.index ["created_by_id"], name: "index_tools_on_created_by_id"
    t.index ["slug"], name: "index_tools_on_slug", unique: true
    t.index ["status"], name: "index_tools_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.datetime "updated_at", null: false
    t.string "every_user_id"
    t.string "name"
    t.string "avatar_url"
    t.string "handle"
    t.string "bio"
    t.boolean "public", default: false, null: false
    t.boolean "admin", default: false, null: false
    t.datetime "loadout_updated_at"
    t.datetime "onboarded_at"
    t.string "visibility", default: "only_me", null: false
    t.boolean "email_verified", default: false, null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["every_user_id"], name: "index_users_on_every_user_id", unique: true
    t.index ["handle"], name: "index_users_on_handle", unique: true
  end

  create_table "visibility_periods", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "level", null: false
    t.datetime "starts_at", null: false
    t.datetime "ends_at"
    t.index ["user_id", "starts_at"], name: "index_visibility_periods_on_user_id_and_starts_at"
    t.index ["user_id"], name: "index_visibility_periods_one_open_per_user", unique: true, where: "ends_at IS NULL"
    t.check_constraint "level IN ('team', 'link')", name: "visibility_periods_level_check"
  end

  add_foreign_key "ai_models", "users", column: "created_by_id", on_delete: :nullify
  add_foreign_key "entries", "ai_models"
  add_foreign_key "entries", "categories"
  add_foreign_key "entries", "tools"
  add_foreign_key "entries", "users", on_delete: :cascade
  add_foreign_key "entry_changes", "ai_models"
  add_foreign_key "entry_changes", "categories"
  add_foreign_key "entry_changes", "tools"
  add_foreign_key "entry_changes", "users", on_delete: :cascade
  add_foreign_key "geneva_drive_step_executions", "geneva_drive_workflows", column: "workflow_id", on_delete: :cascade
  add_foreign_key "oauth_authorization_codes", "oauth_clients"
  add_foreign_key "oauth_authorization_codes", "oauth_grants"
  add_foreign_key "oauth_authorization_codes", "users"
  add_foreign_key "oauth_grants", "oauth_clients"
  add_foreign_key "oauth_grants", "users"
  add_foreign_key "pick_suggestions", "ai_models", on_delete: :cascade
  add_foreign_key "pick_suggestions", "categories", on_delete: :cascade
  add_foreign_key "pick_suggestions", "tools", on_delete: :cascade
  add_foreign_key "pick_suggestions", "users", on_delete: :cascade
  add_foreign_key "sessions", "users"
  add_foreign_key "tools", "users", column: "created_by_id", on_delete: :nullify
  add_foreign_key "visibility_periods", "users", on_delete: :cascade
end
