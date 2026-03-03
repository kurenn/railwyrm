# frozen_string_literal: true

class Application < ApplicationRecord
  belongs_to :candidate
  belongs_to :job_posting
  belongs_to :pipeline_stage
  belongs_to :owner, polymorphic: true, optional: true

  has_many :application_events, dependent: :destroy
  has_many :interviews, dependent: :destroy
  has_many :offers, dependent: :destroy

  enum :status, {
    applied: 0,
    screening: 1,
    interview: 2,
    offer: 3,
    hired: 4,
    rejected: 5
  }, default: :applied

  validates :candidate_id, uniqueness: { scope: :job_posting_id }

  after_create_commit :audit_created
  after_update_commit :audit_changes

  private

  def audit_created
    create_event!("application_created", metadata: { status: status, stage_id: pipeline_stage_id })
  end

  def audit_changes
    if saved_change_to_status?
      create_event!("status_changed", metadata: { from: status_before_last_save, to: status })
    end

    return unless saved_change_to_pipeline_stage_id?

    create_event!(
      "stage_changed",
      metadata: {
        from_stage_id: pipeline_stage_id_before_last_save,
        to_stage_id: pipeline_stage_id
      }
    )
  end

  def create_event!(event_type, metadata: {})
    return unless defined?(ApplicationEvent)

    application_events.create!(
      event_type: event_type,
      occurred_at: Time.current,
      actor: Current.user || owner,
      metadata: metadata
    )
  rescue StandardError
    nil
  end
end
