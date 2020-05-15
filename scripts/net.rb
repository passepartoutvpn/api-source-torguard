require "json"
require "resolv"
require "ipaddr"
require "nokogiri"

cwd = File.dirname(__FILE__)
Dir.chdir(cwd)
load("util.rb")

###

servers_html = File.open("../template/servers.html") { |f| Nokogiri::HTML(f) }
ca = File.read("../static/ca.crt")
tls_auth = read_tls_wrap("auth", 1, "../static/ta.key", 4, 20)
tls_crypt = read_tls_wrap("auth", 1, "../static/ta.key", 4, 20)
domain = "secureconnect.me"
#domain = "torguardvpnaccess.com"

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
    eku: true,
    ping: 5
}

cfg_default = cfg.dup
cfg_default["cipher"] = "AES-256-GCM"
cfg_default["auth"] = "SHA256"
cfg_default["ep"] = [
    "UDP:1912",
    "UDP:1195",
    "TCP:1912",
    "TCP:1195"
]
cfg_default["wrap"] = tls_auth
cfg_default["frame"] = 2
cfg_default["compression"] = 0

cfg_strong = cfg.dup
cfg_strong["cipher"] = "AES-256-GCM"
cfg_strong["auth"] = "SHA512"
cfg_strong["ep"] = [
    "UDP:1215",
    "UDP:389",
    "TCP:1215",
    "TCP:389"
]
cfg_strong["wrap"] = tls_auth
cfg_strong["frame"] = 2
cfg_strong["compression"] = 0

cfg_comp = cfg.dup
cfg_comp["cipher"] = "AES-128-CBC"
cfg_comp["auth"] = "SHA256"
cfg_comp["ep"] = [
    "UDP:53",
    "TCP:53"
]
cfg_comp["wrap"] = tls_crypt
cfg_comp["frame"] = 1
cfg_comp["compression"] = 1

#cfg_sha1 = cfg.dup
#cfg_sha1["cipher"] = "AES-128-GCM"
#cfg_sha1["auth"] = "SHA1"
#cfg_sha1["ep"] = [
#    "UDP:995",
#    "TCP:995"
#]

external = {
    hostname: "${id}.#{domain}"
}

preset_default = {
    id: "preset-default",
    name: "Default",
    comment: "256-bit encryption / 256-bit auth",
    cfg: cfg_default,
    external: external
}
preset_strong = {
    id: "preset-strong",
    name: "Strong",
    comment: "256-bit encryption / 512-bit auth",
    cfg: cfg_strong,
    external: external
}
preset_comp = {
    id: "preset-comp",
    name: "Compatible",
    comment: "128-bit encryption / 256-bit auth",
    cfg: cfg_comp,
    external: external
}
presets = [preset_default, preset_comp, preset_strong]

defaults = {
    :username => "user@mail.com",
    :pool => "us",
    :preset => "preset-default"
}

###

pools = []
servers.each { |s|
    en_country = s[0]
    country = s[0].to_country_code.upcase
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
