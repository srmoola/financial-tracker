# Merchants' and banks' logos and websites, from Plaid.
module LogosHelper
  # A link for a website as Plaid gives it (e.g. "netflix.com").
  def website_url(website)
    return if website.blank?

    website.match?(%r{\Ahttps?://}i) ? website : "https://#{website}"
  end

  # `name`, linking to `website` in a new tab (with a small arrow), or just
  # `name` when there's no website.
  def website_link(name, website, **options)
    return tag.span(name, **options) unless (url = website_url(website))

    link_to url, target: "_blank", rel: "noopener noreferrer", title: "Open #{url.delete_prefix("https://")}", **options do
      safe_join([ name, " ", tag.svg(tag.path(d: "M7 17 17 7M8 7h9v9"), class: "inline size-3 align-baseline text-base-content/40", viewBox: "0 0 24 24",
        fill: "none", stroke: "currentColor", "stroke-width": 2.5, "stroke-linecap": "round", "stroke-linejoin": "round", "aria-hidden": true) ])
    end
  end

  # A merchant's logo, or the first letter of its name when there isn't one.
  def merchant_logo(logo_url, name)
    if logo_url
      image_tag logo_url, alt: "", loading: "lazy", class: "size-10 shrink-0 rounded-xl border border-base-300 bg-white object-contain p-1"
    else
      tag.div name.first.upcase, class: "grid size-10 shrink-0 place-items-center rounded-xl bg-base-200 text-sm font-semibold", aria: { hidden: true }
    end
  end
end
