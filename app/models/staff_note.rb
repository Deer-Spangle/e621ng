class StaffNote < ApplicationRecord
  belongs_to :creator, :class_name => "User"
  belongs_to :user

  after_create :add_audit_entry

  module SearchMethods
    def for_creator(user_id)
      user_id.present? ? where("creator_id = ?", user_id) : none
    end

    def for_creator_name(user_name)
      for_creator(User.name_to_id(user_name))
    end

    def for_user(user_id)
      user_id.present? ? where('creator_id  = ?', user_id) : none
    end

    def for_user_name(user_name)
      for_user(User.name_to_id(user_name))
    end

    def search(params)
      q = super

      if params[:resolved]
        q = q.attribute_matches(:resolved, params[:resolved])
      end

      if params[:user_name].present?
        q = q.for_user_name(params[:user_name])
      end

      if params[:creator_name].present?
        q = q.for_creator_name(params[:creator_name])
      end
      q.apply_default_order(params)
    end

    def default_order
      order("resolved asc, id desc")
    end
  end

  extend SearchMethods


  def add_audit_entry
    StaffAuditLog.log(:staff_note_add, creator, {user_id: user_id})
  end

  def resolve!
    self.resolved = true
    save
  end

  def unresolve!
    self.resolved = false
    save
  end
end
