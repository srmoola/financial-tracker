# The user's own avatar: shown in the app, uploaded and removed on Settings.
class AvatarsController < ApplicationController
  def show
    avatar = Current.user.avatar or return head(:not_found)

    expires_in 1.year, private: true # the URL changes with the avatar (see User#avatar_version)
    send_data avatar.image, type: Avatar::CONTENT_TYPE, disposition: "inline"
  end

  def update
    avatar = Current.user.avatar || Current.user.build_avatar

    if avatar.update(upload: params[:avatar])
      redirect_to settings_path, notice: "Your photo is updated.", status: :see_other
    else
      redirect_to settings_path, alert: avatar.errors.full_messages.to_sentence, status: :see_other
    end
  end

  def destroy
    Current.user.avatar&.destroy!
    redirect_to settings_path, notice: "Your photo is removed.", status: :see_other
  end
end
