require "json"
require "resolv"
require "ipaddr"
require "nokogiri"

cwd = File.dirname(__FILE__)
Dir.chdir(cwd)
load "util.rb"
load "country_codes.rb"

###

template = File.open("../template/servers.html") { |f| Nokogiri::HTML(f) }
ca = File.read("../static/ca.crt")
tls_crypt = read_tls_wrap("crypt", 1, "../static/ta.key", 4)
domain = "torguard.org"

template = template.xpath("//td[contains(text(), '#{domain}')]").select { |s|
  !s.previous_element().previous_element().nil?
}

template.map! { |s|
  a = s.previous_element()
  c = a.previous_element()
  hostname = s.text()
  en_country = c.text()
  area = a.text()
  [en_country, hostname, area]
}

cfg = {
  ca: ca,
  compressionFraming: 1,
  compressionAlgorithm: 1,
  checksEKU: true,
  keepAliveInterval: 5,
  keepAliveTimeout: 30
}

cfg_default = cfg.dup
cfg_default["cipher"] = "AES-128-GCM"
cfg_default["digest"] = "SHA1"

cfg_strong = cfg.dup
cfg_strong["cipher"] = "AES-256-GCM"
cfg_strong["digest"] = "SHA256"
cfg_strong["tlsWrap"] = tls_crypt

preset_default = {
  id: "default",
  name: "Default",
  comment: "128-bit encryption",
  ovpn: {
    cfg: cfg_default,
    endpoints: [
      "UDP:80",
      "UDP:443",
      "UDP:995",
      "TCP:80",
      "TCP:443",
      "TCP:995"
    ]
  }
}
preset_strong = {
  id: "strong",
  name: "Strong",
  comment: "256-bit encryption",
  ovpn: {
    cfg: cfg_strong,
    endpoints: [
      "UDP:53",
      "UDP:501",
      "UDP:1198",
      "UDP:9201",
      "TCP:53",
      "TCP:501",
      "TCP:1198",
      "TCP:9201"
    ]
  }
}
presets = [preset_default, preset_strong]

defaults = {
  :username => "user@mail.com",
  :country => "US"
}

###

servers = []
template.each { |s|
  en_country = s[0]
  country = s[0].to_country_code
  raise "Not found '#{en_country}'" if country.nil?
  country = country.upcase
  hostname = s[1]
  id_comps = hostname.split(".")
  id_comps.pop # "org"
  id_comps.pop # "torguard"
  id = id_comps.join(".").downcase
  area = s[2]

  # normalize Serbia
  if country == "SRB" then
    country = "RS"
  end

  addresses = nil
  if ARGV.include? "noresolv"
    addresses = []
    #addresses = ["1.2.3.4"]
  else
    addresses = Resolv.getaddresses(hostname)
  end
  addresses.map! { |a|
    IPAddr.new(a).to_i
  }

  server = {
    :id => id,
    :country => country
  }
  server[:hostname] = hostname
  server[:addrs] = addresses
  server[:area] = area if !area.nil?
  servers << server
}

###

infra = {
  :servers => servers,
  :presets => presets,
  :defaults => defaults
}

puts infra.to_json
puts
