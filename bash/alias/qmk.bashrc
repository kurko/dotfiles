# QMK
#
# I always forget what I need to type to update my keyboard. Here you go.
function qmk-firmware-setup {
  qmk setup
}

function qmk-push-kyria {
  qmk flash -kb kyria -km kurko
}

# Deprecated
function qmk-push-kyria-json() {
  qmk flash -kb kyria -bl dfu $DOTFILES/qmk/kyria/kyria-alex-default.json
}
