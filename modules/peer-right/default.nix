{ ... }:
let

  nodeIn = {
    hooks = [ { type = "stats"; } ];
  };

  nodes = {
    peer_left_webrtc = {
      type = "webrtc";

      session = "neis1234";
      server = "http://server:8080";
      wait_seconds = 10;
      format = "villas.binary";

      "in" = nodeIn;
    };

    peer_left_mqtt = {
      type = "mqtt";

      host = "server";
      format = "villas.binary";

      "in" = {
        subscribe = "neis";
      } // nodeIn;

      out = {
        publish = "neis";
      };
    };

    peer_left_udp = {
      type = "socket";

      layer = "udp";
      format = "villas.binary";

      "in" = {
        address = "*:12000";
      } // nodeIn;

      out = {
        address = "peer-left:12000";
      };
    };

    peer_left_websocket = {
      type = "websocket";

      format = "villas.binary";

      "in" = nodeIn;
    };

    peer_left_sampled_values = {
      type = "iec61850-9-2";

      interface = "eth1";

      "in" = {
        signals = {
          count = 64;
          type = "float";
          iec_type = "float32";
        };
      } // nodeIn;

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
  };

  loopbackConfig = typ: {
    inherit nodes;

    paths = [
      {
        "in" = "peer_left_${typ}";
        out = "peer_left_${typ}";
      }
    ];

    http = {
      port = 8080;
    };
  };

  types = [
    "webrtc"
    "mqtt"
    "udp"
    "websocket"
    "sampled_values"
  ];
in
{
  imports = [ ../peer ];

  networking.hostName = "peer-right";

  environment.etc = builtins.listToAttrs (
    map (type: {
      name = "villas-node-${type}.json";
      value = {
        text = builtins.toJSON (loopbackConfig type);
        mode = "0644";
      };
    }) types
  );
}
