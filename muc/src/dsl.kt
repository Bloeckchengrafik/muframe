@file:Suppress("PropertyName") // stick to muc naming convention

package muc

@DslMarker
annotation class MucDslMarker

class GeneralPurposeRegister(val index: Int) {
    val encoding: Int = index
}
class MicrocodeRegister(val index: Int) {
    val encoding: Int = index + 16
}

@MucDslMarker
class InstructionDsl {
    val GPR = Array(16) { GeneralPurposeRegister(it) }
    val MUR = Array(4) { MicrocodeRegister(it) }
}

class Immediate(val width: Int)

data class RRInstructionParams(
    val R1: GeneralPurposeRegister,
    val R2: GeneralPurposeRegister,
)

data class RXInstructionParams(
    val R1: GeneralPurposeRegister,
    val X2: GeneralPurposeRegister,
    val B2: GeneralPurposeRegister,
    val D2: Immediate
)

data class SIInstructionParams(
    val I2: Immediate,
    val B1: GeneralPurposeRegister,
    val D1: Immediate
)

data class RSInstructionParams(
    val R1: GeneralPurposeRegister,
    val R3: GeneralPurposeRegister,
    val B2: GeneralPurposeRegister,
    val D2: Immediate
)

data class SSOneInstructionParams(
    val L: Immediate,
    val B1: GeneralPurposeRegister,
    val D1: Immediate,
    val B2: GeneralPurposeRegister,
    val D2: Immediate
)

data class SSTwoInstructionParams(
    val L1: Immediate,
    val L2: Immediate,
    val B1: GeneralPurposeRegister,
    val D1: Immediate,
    val B2: GeneralPurposeRegister,
    val D2: Immediate
)

@MucDslMarker
class MucDsl {
    fun rrType(name: String, opcode: Int, block: InstructionDsl.(RRInstructionParams) -> Unit) {

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
