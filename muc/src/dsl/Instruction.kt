package muc.dsl

enum class Opcode(val opcode: Int) {
    LDI32(0b00),
    ALU(0b01),
    MEMDo(0b10),
    MEMWait(0b11),
}

sealed interface Operation {
    val opcode: Opcode

    data class LDI32(
        val dst: Destination,
        val imm32: Int
    ) : Operation {
        override val opcode: Opcode = Opcode.LDI32
    }

    data class ALU(
        val dst: Destination,
        val srcA: Source,
        val srcB: Source,
        val operation: AluOp,
        val width: AluWidth
    ) : Operation {
        override val opcode: Opcode = Opcode.ALU
    }

    data class MEMRead(
        val value: Destination,
        val address: Source,
        val synchronous: Boolean,
        val width: MemWidth,
    ) : Operation {
        override val opcode: Opcode = Opcode.MEMDo
    }

    data class MEMWrite(
        val value: Source,
        val address: Source,
        val synchronous: Boolean,
        val width: MemWidth,
    ) : Operation {
        override val opcode: Opcode = Opcode.MEMDo
    }

    data object MEMWait : Operation {
        override val opcode: Opcode = Opcode.MEMWait
    }
}

enum class AluOp(val encoding: Int) {
    PassA(0),
    Add(1),
    Sub(2),
    And(3),
    Or(4),
    Xor(5),
    NotA(6),
    ShiftLeft(7),
    ShiftRight(8),
    ShiftArithmeticRight(9),
    RotateLeft(10),
    RotateRight(11),
    AddCarry(12),
    SubCarry(13),
    SignExtend8(14),
    SignExtend16(15),
    ZeroExtend8(16),
    ZeroExtend16(17),
    Swap16(18),
    ByteSwap(19)
}

enum class AluWidth(val encoding: Int) {
    Nibble(0),
    Byte(1),
    HalfWord(2),
    Word(3)
}

enum class MemWidth(val encoding: Int) {
    Byte(0),
    HalfWord(1),
    Word(2)
}

data class Flags(
    val s: Boolean
) {
    operator fun plus(other: Flags): Flags {
        return Flags(s || other.s)
    }
}

enum class Condition(val value: Int) {
    Always(0b0000),
    Never(0b0001),
    Equal(0b0010),
    NotEqual(0b0011),
    CarrySet(0b0100),
    CarryClear(0b0101),
    Negative(0b0110),
    NonNegative(0b0111),
    OverflowSet(0b1000),
    OverflowClear(0b1001),
    UnsignedGreater(0b1010),
    UnsignedLessOrEqual(0b1011),
    SignedGreaterOrEqual(0b1100),
    SignedLess(0b1101),
    SignedGreater(0b1110),
    SignedLessOrEqual(0b1111)
}

data class MuInstruction<T : Operation>(
    var operation: T,
    var flags: Flags = Flags(false),
    var condition: Condition = Condition.Always,
)

