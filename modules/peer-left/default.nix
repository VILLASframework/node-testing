let
  nodes = prefix: {
    testdata = {
      type = "test_rtt";

      cases = [
        {
          duration = 10;
          rates = [
            10
            100
            1000
          ];
          values = [
            10
            # 100
            # 1000
          ];
        }
      ];

      cooldown = 5;
      format = "villas.human";
      output = "/home/stv0g/neis/results";
      prefix = "test_rtt_${prefix}_%y-%m-%d_%H-%M-%S";
    };

    peer_right_webrtc = {
      type = "webrtc";

      server = "http://server:8080";
      session = "neis1234";
      format = "villas.binary";

      wait_seconds = 10;
    };

    peer_right_mqtt = {
      type = "mqtt";

      host = "server";
      format = "villas.binary";

      "in" = {
        subscribe = "neis";
      };

      out = {
        publish = "neis";
      };
    };

    peer_right_udp = {
      type = "socket";

      layer = "udp";
      format = "villas.binary";

      "in" = {
        address = "*:12000";
      };

      out = {
        address = "peer-right:12000";
      };
    };

    peer_right_websocket = {
      type = "websocket";

      format = "villas.binary";

      destinations = [ "ws://peer-right:8080/peer_left_websocket" ];
    };

    peer_right_sampled_values = {
      type = "iec61850-9-2";

      interface = "eth1";

      "in" = {
        signals = {
          count = 64;
          type = "float";
          iec_type = "float32";
        };
      };

      out = {
        svid = "1234";

        signals = {
          count = 64;
          type = "float";
          iec_type = "float32";
        };

        vlan.enabled = false;
      };
    };

    peer_right_loopback = {
      type = "loopback";
    };
  };

  config = typ: {
    idle_stop = true; # Stop villas-node after test has been completed

    nodes = nodes typ;

    paths = [
      {
        "in" = "testdata";
        out = "peer_right_${typ}";
      }
      {
        "in" = "peer_right_${typ}";
        out = "testdata";
      }
    ];
  };

  types = [
    "webrtc"
    "mqtt"
    "udp"
    "websocket"
    "sampled_values"
    "loopback"
  ];
in
{
  imports = [ ../peer ];

  networking.hostName = "peer-left";

  environment.etc = builtins.listToAttrs (
    map (type: {
      name = "villas-node-${type}.json";
      value = {
        text = builtins.toJSON (config type);
        mode = "0644";
      };
    }) types
  );
}
