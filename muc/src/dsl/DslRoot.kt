@file:Suppress("PropertyName", "UnusedReceiverParameter") // stick to muc naming convention

package muc.dsl

@DslMarker
annotation class MucDslMarker

data class DslAluOperation(
    val a: Source,
    val b: Source,
    val operation: AluOp,
    val width: AluWidth
)

data class Label(val nextIndex: Int)
object MemInst

enum class MemoryAccess(val sync: Boolean) {
    Sync(true), Async(false)
}

@MucDslMarker
class InstructionDsl : Values by ValuesImpl() {
    val updateFlags = Flags(true)
    val Memory = MemInst

    internal val instructions = mutableListOf<MuInstruction<*>>()

    infix fun Destination.load(imm: Int): MuInstruction<Operation.LDI32> {
        return MuInstruction(
            Operation.LDI32(this, imm)
        ).also { instructions.add(it) }
    }

    infix fun Destination.load(value: Source): MuInstruction<Operation.ALU> {
        return MuInstruction(
            Operation.ALU(
                this,
                value,
                zero,
                AluOp.PassA,
                AluWidth.Word
            )
        ).also { instructions.add(it) }
    }

    infix fun Destination.load(label: Label): MuInstruction<Operation.LDI32> {
        return MuInstruction(
            Operation.LDI32(this, label.nextIndex)
        ).also { instructions.add(it) }
    }

    fun alu(
        a: Source,
        operation: AluOp,
        b: Source,
        width: AluWidth = AluWidth.Word
    ): DslAluOperation = DslAluOperation(a, b, operation, width)

    infix fun Destination.load(op: DslAluOperation): MuInstruction<Operation.ALU> {
        return MuInstruction(
            Operation.ALU(
                this,
                op.a,
                op.b,
                op.operation,
                op.width
            )
        ).also { instructions.add(it) }
    }

    fun MemInst.read(address: Source, into: Destination, access: MemoryAccess = MemoryAccess.Sync, width: MemWidth = MemWidth.Word): MuInstruction<Operation.MEMRead> {
        return MuInstruction(
            Operation.MEMRead(
                into,
                address,
                access.sync,
                width
            )
        ).also { instructions.add(it) }
    }

    fun MemInst.write(value: Source, address: Source, access: MemoryAccess = MemoryAccess.Sync, width: MemWidth = MemWidth.Word): MuInstruction<Operation.MEMWrite> {
        return MuInstruction(
            Operation.MEMWrite(
                value,
                address,
                access.sync,
                width
            )
        ).also { instructions.add(it) }
    }

    fun label(): Label {
        return Label(instructions.size)
    }

    fun MuInstruction<Operation.MEMRead>.await(): MuInstruction<Operation.MEMWait> {
        return MuInstruction(
            Operation.MEMWait
        ).also { instructions.add(it) }
    }

    fun MuInstruction<Operation.MEMWrite>.await(): MuInstruction<Operation.MEMWait> {
        return MuInstruction(
            Operation.MEMWait
        ).also { instructions.add(it) }
    }

    infix fun <T : Operation> MuInstruction<T>.on(condition: Condition): MuInstruction<T> {
        return this.also { it.condition = condition }
    }

    infix fun <T : Operation> MuInstruction<T>.with(flags: Flags): MuInstruction<T> {
        return this.also { it.flags = flags }
    }
}

data class RRInstructionParams(
    val R1: RegParameter,
    val R2: RegParameter,
)

data class RXInstructionParams(
    val R1: RegParameter,
    val X2: RegParameter,
    val B2: RegParameter,
    val D2: Immediate12BitParameter
)

data class SIInstructionParams(
    val I2: Immediate8BitParameter,
    val B1: RegParameter,
    val D1: Immediate12BitParameter
)

data class RSInstructionParams(
    val R1: RegParameter,
    val R3: RegParameter,
    val B2: RegParameter,
    val D2: Immediate12BitParameter
)

data class SSOneInstructionParams(
    val L: Immediate8BitParameter,
    val B1: RegParameter,
    val D1: Immediate12BitParameter,
    val B2: RegParameter,
    val D2: Immediate12BitParameter
)

data class SSTwoInstructionParams(
    val L1: Immediate4BitParameter,
    val L2: Immediate4BitParameter,
    val B1: RegParameter,
    val D1: Immediate12BitParameter,
    val B2: RegParameter,
    val D2: Immediate12BitParameter
)

enum class InstructionType(val ident: Int) {
    Invalid(0), RR(1), RX(2), SI(3), RS(4), SS(5),
}

fun ByteArray.put48(offset: Int, value: Long) {
    require(value in 0..0xFFFF_FFFF_FFFFL) { "Value must fit in 48 bits" }
    require(offset >= 0 && offset <= size - 6) { "Not enough space" }

    for (i in 0 until 6) {
        this[offset + i] = (value ushr (40 - 8 * i)).toByte()
    }
}

private fun buildJumpTableEntry(type: InstructionType, offset: UInt): UInt {
    return type.ident.toUInt() shl 29 or offset
}

@MucDslMarker
class MucDsl {
    private val metaTable = Array(256) { 0.toUInt() }
    private val data = ByteArray(0x10000)
    private var nextAddr = 0
    private var nextIdx = 0

    fun rrType(name: String, opcode: Byte, block: InstructionDsl.(RRInstructionParams) -> Unit) {
        val params = RRInstructionParams(RegParameter(16), RegParameter(17))
        val jumpTableEntry = buildJumpTableEntry(InstructionType.RR, nextIdx.toUInt())
        metaTable[opcode.toInt()] = jumpTableEntry

        val instructions = InstructionDsl()
            .apply { block(params) }
            .instructions
            .map { it.encode() }
    }

    fun rxType(name: String, opcode: Int, block: InstructionDsl.(RXInstructionParams) -> Unit) {

    }

    fun siType(name: String, opcode: Int, block: InstructionDsl.(SIInstructionParams) -> Unit) {

    }

    fun rsType(name: String, opcode: Int, block: InstructionDsl.(RSInstructionParams) -> Unit) {

    }

    fun ssSingleLenType(name: String, opcode: Int, block: InstructionDsl.(SSOneInstructionParams) -> Unit) {

    }

    fun ssTwoLenType(name: String, opcode: Int, block: InstructionDsl.(SSTwoInstructionParams) -> Unit) {

    }
}
