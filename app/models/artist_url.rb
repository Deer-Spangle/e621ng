class ArtistUrl < ApplicationRecord
  before_validation :initialize_normalized_url, on: :create
  before_validation :normalize
  validates :url, presence: true, uniqueness: { scope: :artist_id }
  validates :url, length: { in: 1..4096 }
  validate :validate_url_format
  belongs_to :artist, :touch => true

  scope :url_matches, ->(url) { url_attribute_matches(:url, url) }
  scope :normalized_url_matches, ->(url) { url_attribute_matches(:normalized_url, url) }

  def self.parse_prefix(url)
    prefix, url = url.match(/\A(-)?(.*)/)[1, 2]
    is_active = prefix.nil?

    [is_active, url]
  end

  def self.normalize(url)
    if url.nil?
      nil
    else
      url = url.sub(%r!^https://!, "http://")
      url = url.sub(%r!^http://([^/]+)!i) { |domain| domain.downcase }

      url = url.gsub(/\/+\Z/, "")
      url = url.gsub(%r!^https://!, "http://")
      url + "/"
    end
  end

  def self.search(params = {})
    q = super

    q = q.attribute_matches(:artist_id, params[:artist_id])
    q = q.attribute_matches(:is_active, params[:is_active])
    q = q.search_text_attribute(:url, params)
    q = q.search_text_attribute(:normalized_url, params)

    if params[:artist_name].present?
      q = q.joins(:artist).where("artists.name = ?", params[:artist_name])
    end

    # Legacy param?
    q = q.artist_matches(params[:artist])
    q = q.url_matches(params[:url_matches])
    q = q.normalized_url_matches(params[:normalized_url_matches])

    case params[:order]
    when /\A(id|artist_id|url|normalized_url|is_active|created_at|updated_at)(?:_(asc|desc))?\z/i
      dir = $2 || :desc
      q = q.order($1 => dir).order(id: :desc)
    else
      q = q.apply_default_order(params)
    end

    q
  end

  def self.artist_matches(params = {})
    return all if params.blank?
    where(artist_id: Artist.search(params).reorder(nil))
  end

  def self.url_attribute_matches(attr, url)
    if url.blank?
      all
    elsif url =~ %r!\A/(.*)/\z!
      where_regex(attr, $1)
    elsif url.include?("*")
      where_ilike(attr, url)
    else
      where(attr => normalize(url))
    end
  end

  # sites apearing at the start have higher priority than those below
  SITES_PRIORITY_ORDER = [
    "furaffinity.net",
    "deviantart.com",
    "twitter.com",
    "pixiv.net",
    "inkbunny.net",
    "sofurry.com",
    "weasyl.com",
    "furrynetwork.com",
    "tumblr.com",
    "newgrounds.com",
    "hentai-foundry.com",
    "artstation.com",
    "baraag.net",
    "pawoo.net",
    "pillowfort.social",
    "reddit.com",
    "youtube.com",
    "instagram.com",
    "vk.com",
    "facebook.com",
    # livestreams
    "picarto.tv",
    "piczel.tv",
    "twitch.tv",
    # support the artist
    "patreon.com",
    "subscribestar.adult",
    "ko-fi.com",
    "commishes.com",
    "fanbox.cc",
    "gumroad.com",
    "redbubble.com",
    # misc
    "discord.gg",
    "trello.com",
    "curiouscat.me",
    "toyhou.se",
    "linktr.ee",
    "carrd.co",
  ].reverse!

  # higher priority will apear higher in the artist url list
  # inactive urls will be pushed to the bottom
  def priority
    prio = 0
    prio -= 1000 unless is_active
    host = Addressable::URI.parse(url).domain
    prio += SITES_PRIORITY_ORDER.index(host).to_i
    prio
  end

  def normalize
    self.normalized_url = self.class.normalize(url)
  end

  def initialize_normalized_url
    self.normalized_url = url
  end

  def to_s
    if is_active?
      url
    else
      "-#{url}"
    end
  end

  def validate_url_format
    uri = Addressable::URI.parse(url)
    errors.add(:url, "'#{uri}' must begin with http:// or https:// ") if !uri.scheme.in?(%w[http https])
  rescue Addressable::URI::InvalidURIError => error
    errors.add(:url, "'#{uri}' is malformed: #{error}")
  end
end
