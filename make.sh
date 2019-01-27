#!/bin/sh

if (fasm main.asm >> /dev/null)
then
    bochs -f a.bxrc -q
fi

