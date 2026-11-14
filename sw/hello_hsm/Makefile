Z390_BIN=/opt/z390/bash
Z390_ASM=$(Z390_BIN)/asml

OBJ=hello_hsm

compile: $(OBJ).MLC
	$(Z390_ASM) $(OBJ) MOD AMODE24
