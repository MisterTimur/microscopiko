#!/bin/sh

if (fasm main.asm >> /dev/null)
then

    mv main.bin floppy/coreboot.bin
    bochs -f a.bxrc -q
fi

