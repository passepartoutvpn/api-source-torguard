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
tls_wrap = read_tls_wrap("auth", 1, "../static/ta.key", 4, 20)
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
    wrap: tls_wrap,
    ep: [
        "UDP:1912",
        "UDP:1195",
        "TCP:1912",
        "TCP:1195"
    ],
    cipher: "AES-256-GCM",
    auth: "SHA256",
    frame: 2,
    compression: 0,
    eku: true,
    ping: 5
}

external = {
    hostname: "${id}.#{domain}"
}

recommended = {
    id: "default",
    name: "Default",
    comment: "256-bit encryption",
    cfg: cfg,
    external: external
}
presets = [recommended]

defaults = {
    :username => "user@mail.com",
    :pool => "us",
    :preset => "default"
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
