# QMK
#
# I always forget what I need to type to update my keyboard. Here you go. Step
# one after installing QMK (via Homebrew) is to run `qmk setup`.
function qmk-firmware-setup {
  qmk setup -H ~/www/qmk_firmware
}


# QMK User Space
# https://docs.qmk.fm/newbs_external_userspace
#
# Sets the userspace directory. This is necessary
function qmk-set-userspace {
  # Depending on the machine I'm in, qmk_userspace is generally in
  # ~/www/qmk_userspace. If it it's not, it will use ./qmk_userspace.
  if [ -d ~/www/qmk_userspace ]; then
    qmk config user.overlay_dir=~/www/qmk_userspace
  else
    qmk config user.overlay_dir="$(realpath qmk_userspace)"
  fi
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
  qmk flash -kb splitkb/aurora/sweep/rev1 -km kurko -e CONVERT_TO=liatris
}

# Deprecated
function qmk-push-kyria-json() {
  qmk flash -kb kyria -bl dfu $DOTFILES/qmk/kyria/kyria-alex-default.json
}
