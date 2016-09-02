override["sensu"]["enterprise"]["repo_protocol"] = "https"
override["sensu"]["enterprise"]["version"] = "1.14.8-1"
override["sensu"]["enterprise-dashboard"]["version"] = "1.12.0-1"
override["sensu"]["enterprise-dashboard"]["sensu"] = [
  {
    "name" => "solodev",
    "host" => "127.0.0.1",
    "port" => 4567,
    "ssl" => false,
    "timeout" => 5
  }
]
