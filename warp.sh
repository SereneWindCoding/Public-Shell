#!/usr/bin/env bash

echo y|bash <(curl -fsSL git.io/warp.sh) s5
echo y|bash <(curl -fsSL git.io/warp.sh) proxy
shutdown -r now