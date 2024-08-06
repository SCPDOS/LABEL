#!/bin/sh

buffer:
	nasm label.asm -o ./bin/LABEL.COM -f bin -l ./lst/label.lst -O0v
