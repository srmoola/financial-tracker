module AvatarsHelper
  # The user's photo, or their initials on a dark circle without one.
  def user_avatar(user, size: "size-9", text: "text-sm")
    if (version = user.avatar_version)
      image_tag avatar_path(v: version), alt: "", class: "#{size} shrink-0 rounded-full object-cover"
    else
      tag.div tag.span(user.initials, class: "#{text} font-semibold"), class: "grid #{size} shrink-0 place-items-center rounded-full bg-primary text-primary-content", aria: { hidden: true }
    end
  end
end
