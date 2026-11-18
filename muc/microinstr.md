# Microinstruction Encoding

A microinstuction is always a flow from some source to some destination and does not describe an operation.

## Figments

### Op Target

An operation target is a 6-bit value that specifies the CPU target area of a calculation. Either a GP register or a muc register.
- GPR0-GPR15 are encoded from 0 through 15
- Parameters from the instruction are encoded from 16 onwards. They are RO. Following sizes & mapping are used:
  - {16-19}-4Bit, 20-8Bit, {21,22}-24Bit
  - RR:  16-R1 17-R2
  - RX:  16-R1, 17-B2, 18-X2, 21-D2
  - SI:  16-B1, 20-I2, 21-D1
  - RS:  16-R1, 17-R3, 18-B2, 21-D2
  - SS1: 16-L1, 17-L2, 18-B1, 19-B2, 21-D1, 22-D2
  - SS2: 16-B1, 17-B2, 20-L, 21-D1, 22-D2
- MUC registers are encoded from 32 onwards. MUC registers should be used by lowest number first. Initially, the CPU will have 4 MUC registers. muR0 through muR3.

muR0 is specifically reserved for the muPC. This always starts at 0 per instruction for simplicity. Jumps are thus also only register writes.

GPRs thus have the same encoding in IBM System/360 instructions. 

##
