# SPDX-FileCopyrightText: 2024 Steffen Vogel <steffen.vogel@opal-rt.com>, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0

{ self, system, ... }:
{
  services.coturn = {
    enable = true;
  };
}
