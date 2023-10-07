# QMK
#
# I always forget what I need to type to update my keyboard. Here you go.
function qmk-firmware-setup {
  qmk setup
}

# Kyria: my first split keyboard
#
# To use this, make sure to clone kurko/qmk_firmware (it's possible that the
# code will be in a separate branch).
function qmk-push-kyria {
  qmk flash -kb kyria -km kurko
}

# Aurora Sweep: my second split keyboard
#
# To use this, make sure to clone kurko/qmk_firmware (it's possible that the
# code will be in a separate branch).
function qmk-push-aurora-sweep {
  qmk flash -kb splitkb/aurora/sweep -km kurko -e CONVERT_TO=liatris
}

# Deprecated
function qmk-push-kyria-json() {
  qmk flash -kb kyria -bl dfu $DOTFILES/qmk/kyria/kyria-alex-default.json
}
