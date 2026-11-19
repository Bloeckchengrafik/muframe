# muF Microinstruction Encoding v0.1

The muFrame microinstruction set encoding is not freezed and may change between revisions. All consumers are advised to be in-tree.

There are four types of microinstructions: `LDI32` (00), `ALU` (01), `MEMDo` (10) and `MEMWait` (11). General format: `[47:46]OP [45:7]INSTR [6:4]FLAGS [3:0]COND`

Every microprogram is prefixed by a 32-bit integer indicating the program length in microinstructions. To return to the dispatcher, jump to any address >= program length. Pending memory operations are illegal!

## LDI32

LDI32 loads a 32-Bit immediate value into a target.

`[47:46]00 [45:39]DST [38:7]IMM32 [6:4]FLAGS [3:0]COND`

S flag acts like a `PASS_A` operation with A = IMM32.

## ALU

ALU operations are encoded as `[47:46]01 [45:39]DST [38:32]SRC_A [31:25]SRC_B [24:20]OP [19:18]WIDTH [nres] [6:4]FLAGS [3:0]COND`.

WIDTH is the number of bits used for the operation. The target register write will be zero-extended. Flag calculations are based on WIDTH.

| WIDTH | Description |
| ----- | ----------- |
| 00    | 4-bit       |
| 01    | 8-bit       |
| 10    | 16-bit      |
| 11    | 32-bit      |

OP is the ALU operation to perform:

| OP  | Operation | Description                             | Always Preserved Flags |
| --- | --------- | --------------------------------------- | ---------------------- |
| 0   | PASS_A    | Pass A through                          | CV                     |
| 1   | ADD       | Add A and B                             |                        |
| 2   | SUB       | Subtract B from A                       |                        |
| 3   | AND       | Bitwise AND A and B                     | CV                     |
| 4   | OR        | Bitwise OR A and B                      | CV                     |
| 5   | XOR       | Bitwise XOR A and B                     | CV                     |
| 6   | NOT_A     | Bitwise NOT A                           | CV                     |
| 7   | SHL       | Shift A left by B                       | V                      |
| 8   | SHR       | Shift A right by B                      | V                      |
| 9   | SAR       | Shift A right by B, preserving sign     | V                      |
| 10  | ROL       | Rotate A left by B                      | V                      |
| 11  | ROR       | Rotate A right by B                     | V                      |
| 12  | ADC       | Add A and B, with carry                 |                        |
| 13  | SBC       | Subtract B from A, with carry/no-borrow |                        |
| 14  | SEXT8     | Sign-extend low 8 bits of A             | CV                     |
| 15  | SEXT16    | Sign-extend low 16 bits of A            | CV                     |
| 16  | ZEXT8     | Zero-extend low 8 bits of A             | CV                     |
| 17  | ZEXT16    | Zero-extend low 16 bits of A            | CV                     |
| 18  | SWAP16    | Swap upper and lower 16-bit halves of A | CV                     |
| 19  | BSWAP     | Reverse the four bytes of A             | CV                     |

Rules for the carry flag:

- SUB: C=1 means no borrow
- SBC: A - B - (1 - C)
- ADC: A + B + C

Shifts & Rotates:

- C is the last bit shifted in or out, or preserved when B is 0
- (Shift) If B > WIDTH, zeroes all bits (or ones for SAR with negative A). C contains 0/1 depending on the sign of A.
- (Shift) If B == WIDTH, zeroes/ones the result as above. C contains the last shifted bit.
- (Rotate) With B > WIDTH, shift by B % WIDTH

Width:

SEXT8, SEXT16, ZEXT8, ZEXT16, SWAP16 and BSWAP always operate on 32-bit values. Any other combination is illegal. Instruction-field operands are zero-extended to 32bit.

## MEMDo

MEMDo performs a memory operation, either reading or writing.

`[47:46]10 [45:39]SRC/DST_VAL [38:32]SRC_ADDR [31:31]RW [30:30]SYNC [29:28]WIDTH [nres] [6:4]FLAGS [3:0]COND`

RW: Read/Write. `0` = Read, `1` = Write

SYNC: Synchronous Operation Mode (Wait on completion). `0` = Asynchronous, `1` = Synchronous

WIDTH: Memory access width:

| WIDTH | Description     |
| ----- | --------------- |
| 00    | 1 Byte BYTE     |
| 01    | 2 Byte HALFWORD |
| 10    | 4 Byte WORD     |
| 11    | (reserved)      |

There can only ever be one active memory operation at a time. When SYNC is `0`, any new MEMDo is illegal! Inputs are latched during operation. Asynchronous operations only store the result in DST when MEMWait is called.

S-Bit is only allowed in a synchronous read operation; here, it acts like a `PASS_A` operation with A = result.

For simplicity's sake, I've decided not to draw out a state diagram for memory operations.

## MEMWait

MEMWait waits for a memory operation to complete. Generally, S-Bit is illegal (special case see below). A MEMWait without a MEMDo is a no-op.

`[47:46]11 [nres] [6:4]FLAGS [3:0]COND`

Also writes the result of the operation to DST of MEMDo for asynchronous read operations. Here, S-Bit acts like a `PASS_A` operation with A = result.

## Condition Flags

We adopt ARM condition flags based on microinstruction condition bits `N` (Negative), `Z` (Zero), `C` (Carry) and `V` (Overflow).

| CC   | Condition | Predicate         |
| ---- | --------- | ----------------- |
| 0000 | AL        | `True`            |
| 0001 | NV        | `False`           |
| 0010 | EQ        | `Z`               |
| 0011 | NE        | `!Z`              |
| 0100 | CS        | `C`               |
| 0101 | CC        | `!C`              |
| 0110 | MI        | `N`               |
| 0111 | PL        | `!N`              |
| 1000 | VS        | `V`               |
| 1001 | VC        | `!V`              |
| 1010 | HI        | `C && !Z`         |
| 1011 | LS        | `!C \|\| Z`       |
| 1100 | GE        | `N == V`          |
| 1101 | LT        | `N != V`          |
| 1110 | GT        | `!Z && (N == V)`  |
| 1111 | LE        | `Z \|\| (N != V)` |

## Source / Destination

An operation target is a 7-bit value that specifies the CPU target area of a calculation. Either a GP register or a muc register.

- GPR0-GPR15 are encoded from 0 through 15
- Parameters from the instruction are encoded from 16 onwards. They are RO. Following sizes & mapping are used:
  - {16-19}-4Bit, 20-8Bit, {21,22}-12Bit
  - RR: 16-R1 17-R2
  - RX: 16-R1, 17-B2, 18-X2, 21-D2
  - SI: 16-B1, 20-I2, 21-D1
  - RS: 16-R1, 17-R3, 18-B2, 21-D2
  - SS1: 16-B1, 17-B2, 20-L, 21-D1, 22-D2
  - SS2: 16-L1, 17-L2, 18-B1, 19-B2, 21-D1, 22-D2
- 29 = program length in microinstructions (RO)
- 30 = 0
- 31 = 1
- MUC registers are encoded from 32 onwards. MUC registers should be used by lowest number first. Initially, the CPU will have 8 MUC registers. muR0 through muR7.
- ...psw & co go here right-aligned
- 63 is a DISCARD sink

Bit 6 is the "indirection" flag. When set, it can resolve 4 bit values into registers. Specifically permitted are parameters & muRs.

muR0 is specifically reserved for the muPC. This always starts at 0 per instruction for simplicity. Jumps are thus also only register writes. It advances by 1 per microinstruction if no actual writes are performed, so a skipped write will advance.

GPRs thus have the same encoding in IBM System/360 instructions.

`[6:6]INDIRECT [5:0]RESOURCE_ID`

## Flags

3 Bits controlling ALU logic.

1. (S)tore Flags (LSB)
   Store flags into the NZCV register
2. reserved
3. reserved (MSB)
