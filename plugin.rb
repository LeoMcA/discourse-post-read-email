# name: post-read-email
# about: A plugin to give users the option of marking posts as read when emailed
# version: 0.0.3
# authors: Leo McArdle
# url: https://github.com/mozilla/discourse-post-read-email

enabled_site_setting :post_read_email_enabled

DiscoursePluginRegistry.serialized_current_user_fields << 'mark_post_as_read_on_email'

module EmailSenderExtensions

  def send
    email_log = super
    begin
      return email_log unless SiteSetting.post_read_email_enabled
      return email_log if email_log.kind_of?(SkippedEmailLog)
      if @user&.custom_fields['mark_post_as_read_on_email'] == 't' ||
         @user&.custom_fields['mark_post_as_read_on_email'] == 'true'
        post = Post.find(email_log.post_id) unless email_log.post_id.nil?
        if post
          Notification.where(
            user_id: @user.id,
            topic_id: post.topic_id,
            post_number: post.post_number,
            notification_type: Notification.types[@email_type.to_s.sub('user_', '').to_sym]
          ).update(read: true)
          TopicUser.update_last_read(@user, post.topic_id, post.post_number, 0, 0)
        end
      end
    rescue Exception => e
      Rails.logger.error("Marking post as read after email failed: #{e.message}\n#{e.backtrace.join("\n")}")
    end
    email_log
  end

end

after_initialize do
  Email::Sender.prepend EmailSenderExtensions
end
