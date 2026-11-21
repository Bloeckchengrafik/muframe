package muc.dsl

internal fun encodeField(value: Long, width: Int, offset: Int): ULong {
    require(width in 1..48) { "Field width must be between 1 and 48, got $width" }
    require(offset in 0..(48 - width)) {
        "Field of width $width at offset $offset extends outside the 48-bit instruction"
    }
    require(value >= 0 && value < (1L shl width)) {
        "Field value $value does not fit in $width unsigned bits"
    }
    return value.toULong() shl offset
}

enum class Opcode(val opcode: Int) {
    LDI32(0b00),
    ALU(0b01),
    MEMDo(0b10),
    MEMWait(0b11),
}

interface Awaitable

sealed interface Operation {
    fun encode(): ULong {
        return encodeField(opcode.opcode.toLong(), 2, 46) or encodeContents()
    }

    /**
     * Produce correctly aligned contents for this operation.
     */
    fun encodeContents(): ULong

    val opcode: Opcode

    data class LDI32(
        val dst: Destination,
        val imm32: Int
    ) : Operation {
        override val opcode: Opcode = Opcode.LDI32

        override fun encodeContents(): ULong {
            return encodeField(dst.identifier.toLong(), 7, 39) or
                encodeField(imm32.toUInt().toLong(), 32, 7)
        }
    }

    data class ALU(
        val dst: Destination,
        val srcA: Source,
        val srcB: Source,
        val operation: AluOp,
        val width: AluWidth
    ) : Operation {
        override val opcode: Opcode = Opcode.ALU

        override fun encodeContents(): ULong {
            return encodeField(dst.identifier.toLong(), 7, 39) or
                encodeField(srcA.identifier.toLong(), 7, 32) or
                encodeField(srcB.identifier.toLong(), 7, 25) or
                encodeField(operation.encoding.toLong(), 5, 20) or
                encodeField(width.encoding.toLong(), 2, 18)
        }
    }

    data class MEMRead(
        val value: Destination,
        val address: Source,
        val synchronous: Boolean,
        val width: MemWidth,
    ) : Operation, Awaitable {
        override val opcode: Opcode = Opcode.MEMDo

        override fun encodeContents(): ULong {
            return encodeField(value.identifier.toLong(), 7, 39) or
                encodeField(address.identifier.toLong(), 7, 32) or
                encodeField(if (synchronous) 1 else 0, 1, 30) or
                encodeField(width.encoding.toLong(), 2, 28)
        }
    }

    data class MEMWrite(
        val value: Source,
        val address: Source,
        val synchronous: Boolean,
        val width: MemWidth,
    ) : Operation, Awaitable {
        override val opcode: Opcode = Opcode.MEMDo

        override fun encodeContents(): ULong {
            return encodeField(value.identifier.toLong(), 7, 39) or
                encodeField(address.identifier.toLong(), 7, 32) or
                encodeField(1, 1, 31) or
                encodeField(if (synchronous) 1 else 0, 1, 30) or
                encodeField(width.encoding.toLong(), 2, 28)
        }
    }

    data object MEMWait : Operation {
        override val opcode: Opcode = Opcode.MEMWait

        override fun encodeContents(): ULong {
            return 0.toULong()
        }
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

    /**
     * Produce correctly aligned encoding for this operation.
     */
    fun encode(): ULong {
        val raw = if (s) 0b100L else 0L
        return encodeField(raw, 3, 4)
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
) {
    fun encode(): ULong {
        return operation.encode() or flags.encode() or encodeField(condition.value.toLong(), 4, 0)
    }
}
