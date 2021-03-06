require "json"
require "resolv"
require "ipaddr"
require "nokogiri"

cwd = File.dirname(__FILE__)
Dir.chdir(cwd)
load "util.rb"
load "country_codes.rb"

###

servers_html = File.open("../template/servers.html") { |f| Nokogiri::HTML(f) }
ca = File.read("../static/ca.crt")
tls_auth = read_tls_wrap("auth", 1, "../static/ta.key", 4)
tls_crypt = read_tls_wrap("crypt", 1, "../static/ta.key", 4)
domain = "torguard.com"

servers = servers_html.xpath("//td[contains(text(), '#{domain}')]").select { |s|
    !s.previous_element().previous_element().nil?
}
servers.map! { |s|
  a = s.previous_element()
  c = a.previous_element()
  hostname = s.text()
  en_country = c.text()
  area = a.text()
  [en_country, hostname, area]
}

cfg = {
    ca: ca,
    frame: 1,
    compression: 1,
    eku: true,
    ping: 5,
    pingTimeout: 30
}

cfg_default = cfg.dup
cfg_default["cipher"] = "AES-128-GCM"
cfg_default["auth"] = "SHA1"
cfg_default["ep"] = [
    "UDP:80",
    "UDP:443",
    "UDP:995",
    "TCP:80",
    "TCP:443",
    "TCP:995"
]

cfg_strong = cfg.dup
cfg_strong["cipher"] = "AES-256-GCM"
cfg_strong["auth"] = "SHA256"
cfg_strong["ep"] = [
    "UDP:53",
    "UDP:501",
    "UDP:1198",
    "UDP:9201",
    "TCP:53",
    "TCP:501",
    "TCP:1198",
    "TCP:9201"
]
cfg_strong["wrap"] = tls_crypt

external = {
    hostname: "${id}.#{domain}"
}

preset_default = {
    id: "default",
    name: "Default",
    comment: "128-bit encryption",
    cfg: cfg_default,
    external: external
}
preset_strong = {
    id: "strong",
    name: "Strong",
    comment: "256-bit encryption",
    cfg: cfg_strong,
    external: external
}
presets = [preset_default, preset_strong]

defaults = {
    :username => "user@mail.com",
    :pool => "us",
    :preset => "default"
}

###

pools = []
servers.each { |s|
    en_country = s[0]
    country = s[0].to_country_code
    raise "Not found '#{en_country}'" if country.nil?
    country = country.upcase
    hostname = s[1]
    id = hostname.split(".")[0].downcase
    area = s[2]

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

    pool = {
        :id => id,
        :country => country
    }
    pool[:hostname] = hostname
    pool[:addrs] = addresses
    pool[:area] = area if !area.nil?
    pools << pool
}

###

infra = {
    :pools => pools,
    :presets => presets,
    :defaults => defaults
}

puts infra.to_json
puts
