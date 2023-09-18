"/usr/bin/make" M=$(/bin/pwd) -C "/lib/modules/$(/bin/uname -r)/build" "/lib/modules/$(/bin/uname -r)/build/.config" SUBDIRS=$(/bin/pwd) DRMSRCDIR=$(/bin/pwd) $*
