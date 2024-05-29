# SPDX-FileCopyrightText: 2024 Steffen Vogel <steffen.vogel@opal-rt.com>, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0

{ lib, ... }:
let
  # Test parametrization
  params = {
    modes = [
      "values"
    #   "rates"
    ];

    protocols = [
    #   "mqtt"
    #   "udp"
      # "websocket"
      # "websocket_relayed"
      # "sampled_values"
      "webrtc"
      "webrtc_tcp"
      "webrtc_relayed_udp"
      "webrtc_relayed_tcp"
      # "loopback"
    ];

    rates = [
      1
      2
      4
      8
      16
      32
      64
      128
      256
      512
      1024
      2048
      4096
      8192
    ];

    values = [
      1
      5
      10
      25
      50
      75
      100
      175
      250
      375
      500
    ];
  };

  # Build cartesian product of tests and modes
  testCases = lib.cartesianProductOfSets {
    mode = params.modes;
    protocol = params.protocols;
  };

  # Construct NFTables firewall rules for each test
  rulesNftables =
    testCase:
    (
      let
        sets = {
          peers = "{ 192.168.1.1, 192.168.1.2 }";
          server = "{ 192.168.1.3 }";
        };
        rules = {
          dropP2P = "ip saddr ${sets.peers} drop";
          dropP2PUDP = "ip saddr ${sets.peers} ip protocol udp drop";
          dropIPv6 = "ip6 saddr fe80::/10 drop";
          dropServerUDP = "ip saddr 192.168.1.3 ip protocol udp drop";
        };
      in
      if testCase.protocol == "webrtc_tcp" then
        ''
          table ip my_table {
            chain my_chain {
              type filter hook input priority filter; policy accept;
              ${rules.dropP2PUDP}
            }
          }

          table ip6 my_table {
            chain my_chain {
              type filter hook input priority filter; policy accept;
              ${rules.dropIPv6}
            }
          }
        ''
      else if testCase.protocol == "webrtc_relayed_udp" then
        ''
          table ip my_table {
            chain my_chain {
              type filter hook input priority filter; policy accept;
              ${rules.dropP2P}
            }
          }

          table ip6 my_table {
            chain my_chain {
              type filter hook input priority filter; policy accept;
              ${rules.dropIPv6}
            }
          }
        ''
      else if testCase.protocol == "webrtc_relayed_tcp" then
        ''
          table ip my_table {
            chain my_chain {
              type filter hook input priority filter; policy accept;
              ${rules.dropP2P}
              ${rules.dropServerUDP}
            }
          }

          table ip6 my_table {
            chain my_chain {
              type filter hook input priority filter; policy accept;
              ${rules.dropIPv6}
            }
          }
        ''
      else
        ""
    );

  # Kill remaining VILLASnode instances before starting next test
  setupKillVILLASnodeInstances = testCase: ''
    /run/current-system/sw/bin/killall -9 villas-node || true
  '';

  # Setup NFTables firewall rules
  setupNftables = testCase: ''
    cat << EOF | /run/current-system/sw/bin/nft -f -
      flush ruleset;
      ${rulesNftables testCase}
    EOF
  '';

  # Full setup script for each test
  setup = testCase: (setupKillVILLASnodeInstances testCase) + (setupNftables testCase);

  # Common parts of the VILLASnode configuration
  common = {
    node = {
      "in" = {
        hooks = [ { type = "stats"; } ];
        signals = {
          count = 500;
          type = "float";
        };
      };
    };
  };

  peers = {
    left = rec {
      nodes = testCase: rec {
        testdata = {
          type = "test_rtt";

          duration = 15;
          count = 300;
          mode = "at_least_count";

          cases = [
            (
              if testCase.mode == "rates" then
                {
                  inherit (params) rates;
                  values = [ 10 ];
                }
              else if testCase.mode == "values" then
                {
                  inherit (params) values;
                  rates = [ 100 ];
                }
              else
                { }
            )
          ];

          shutdown = true;
          warmup = 10;
          cooldown = 5;
          format = "csv";
          output = "/home/stv0g/neis/results";
          prefix = "test-rtt_%Y-%m-%d_%H-%M-%S_${testCase.protocol}";
        };

        webrtc = {
          type = "webrtc";

          server = "http://server:8080";
          session = "neis1234";
          format = "villas.binary";

          wait_seconds = 10;

          ice = {
            servers = [
              "turn://server?transport=udp"
              "stun://server?transport=udp"
              "turn://server?transport=tcp"
              "stun://server?transport=tcp"
            ];
          };
        };

        webrtc_tcp = webrtc;
        webrtc_relayed_udp = webrtc;
        webrtc_relayed_tcp = webrtc;

        mqtt = {
          type = "mqtt";

          host = "server";
          format = "villas.binary";

          "in" = {
            subscribe = "neis-right2left";
          };

          out = {
            publish = "neis-left2right";
          };
        };

        udp = {
          type = "socket";

          layer = "udp";
          format = "villas.binary";

          "in" = {
            address = "*:12000";
            inherit (common.node."in") signals;
          };

          out = {
            address = "peer-right:12000";
          };
        };

        websocket = {
          type = "websocket";

          format = "villas.binary";

          destinations = [ "ws://peer-right:8080/websocket" ];
        };

        websocket_relayed_left2right = {
          type = "websocket";

          format = "villas.binary";

          destinations = [ "ws://server:8088/neis-left2right" ];
        };

        websocket_relayed_right2left = {
          type = "websocket";

          format = "villas.binary";

          destinations = [ "ws://server:8088/neis-right2left" ];
        };

        sampled_values = {
          type = "iec61850-9-2";

          interface = "eth1";

          dst_address = "52:54:00:12:01:02";

          "in" = {
            signals = common.node."in".signals // {
              iec_type = "float32";
            };
          };

          out = {
            sv_id = "1234";

            signals = common.node."in".signals // {
              iec_type = "float32";
            };

            vlan.enabled = false;
          };
        };

        loopback = {
          type = "loopback";

          inherit (common.node) "in";
        };

        ngsi = {
          type = "ngsi";

          endpoint = "http://server:1026";
          entity_id = "neis";
          entity_type = "test";

          create = true;
          rate = 1.0e-3;
        };
      };

      config = testCase: {
        idle_stop = true; # Stop villas-node after test has been completed

        nodes = nodes testCase;

        paths =
          if testCase.protocol == "websocket_relayed" then
            [
              {
                "in" = "testdata";
                out = "websocket_relayed_left2right";
              }
              {
                "in" = "websocket_relayed_right2left";
                out = "testdata";
              }
            ]
          else
            [
              {
                "in" = "testdata";
                out = testCase.protocol;
              }
              {
                "in" = testCase.protocol;
                out = "testdata";
              }
            ];
      };
    };

    right = rec {
      nodes = rec {
        webrtc = {
          type = "webrtc";

          session = "neis1234";
          server = "http://server:8080";
          wait_seconds = 10;
          format = "villas.binary";

          inherit (common.node) "in";

          ice = {
            servers = [
              "turn://server?transport=udp"
              "stun://server?transport=udp"
              "turn://server?transport=tcp"
              "stun://server?transport=tcp"
            ];
          };
        };

        webrtc_tcp = webrtc;
        webrtc_relayed_udp = webrtc;
        webrtc_relayed_tcp = webrtc;

        mqtt = {
          type = "mqtt";

          host = "server";
          format = "villas.binary";

          "in" = common.node."in" // {
            subscribe = "neis-left2right";
          };

          out = {
            publish = "neis-right2left";
          };
        };

        udp = {
          type = "socket";

          layer = "udp";
          format = "villas.binary";

          "in" = common.node."in" // {
            address = "*:12000";
          };

          out = {
            address = "peer-left:12000";
          };
        };

        websocket = {
          type = "websocket";

          format = "villas.binary";

          inherit (common.node) "in";
        };

        websocket_relayed_left2right = {
          type = "websocket";

          format = "villas.binary";

          destinations = [ "ws://server:8088/neis-left2right" ];

          inherit (common.node) "in";
        };

        websocket_relayed_right2left = {
          type = "websocket";

          format = "villas.binary";

          destinations = [ "ws://server:8088/neis-right2left" ];
        };

        sampled_values = {
          type = "iec61850-9-2";

          interface = "eth1";

          dst_address = "52:54:00:12:01:01";

          "in" = {
            signals = common.node."in".signals // {
              iec_type = "float32";
            };
            inherit (common.node."in") hooks;
          };

          out = {
            sv_id = "1234";

            signals = common.node."in".signals // {
              iec_type = "float32";
            };

            vlan.enabled = false;
          };
        };

        loopback = {
          type = "loopback";
        };
      };

      config = testCase: {
        inherit nodes;

        paths =
          if testCase.protocol == "websocket_relayed" then
            [
              {
                "in" = "websocket_relayed_left2right";
                out = "websocket_relayed_right2left";
              }
            ]
          else
            [
              {
                "in" = testCase.protocol;
                out = testCase.protocol;
              }
            ];

        http = {
          port = 8080;
        };
      };
    };
  };
in
map (testCase: {
  name = "${testCase.protocol}_${testCase.mode}";
  setup = setup testCase;
  peer_left = peers.left.config testCase;
  peer_right = peers.right.config testCase;
}) testCases
