@file:Suppress("PropertyName") // stick to muc naming convention

package muc.dsl

interface ValueIdentity {
    val identifier: Int
}

interface Source : ValueIdentity
interface Destination : ValueIdentity

open class GeneralPurposeRegister(override val identifier: Int) : Source, Destination

open class Parameter(override val identifier: Int) : Source

class RegParameter(identifier: Int) : Parameter(identifier) {
    fun deref(): GeneralPurposeRegister {
        return GeneralPurposeRegister(identifier and 0b1000000) // set indirection bit
    }
}

class Immediate4BitParameter(identifier: Int) : Parameter(identifier)
class Immediate8BitParameter(identifier: Int) : Parameter(identifier)
class Immediate12BitParameter(identifier: Int) : Parameter(identifier)


class MicrocodeRegister(override val identifier: Int) : Source, Destination {
    fun deref(): GeneralPurposeRegister {
        return GeneralPurposeRegister(identifier and 0b1000000)
    }
}

class SpecialSource(override val identifier: Int) : Source
class SpecialDestination(override val identifier: Int) : Destination

class RegisterFile<T>(val registers: List<T>) {
    operator fun get(index: Int): T {
        return registers[index]
    }
}

interface Values {
    val GPR: RegisterFile<GeneralPurposeRegister>
    val MCR: RegisterFile<MicrocodeRegister>

    val muPC: MicrocodeRegister
    val muPL: SpecialSource
    val zero: SpecialSource
    val one: SpecialSource
    val discard: SpecialDestination

    operator fun RegisterFile<GeneralPurposeRegister>.get(regParam: RegParameter): GeneralPurposeRegister = regParam.deref()
    operator fun RegisterFile<GeneralPurposeRegister>.get(mcrParam: MicrocodeRegister): GeneralPurposeRegister = mcrParam.deref()
}

class ValuesImpl : Values {
    override val GPR: RegisterFile<GeneralPurposeRegister> = RegisterFile((0..15).map { GeneralPurposeRegister(it) })
    override val MCR: RegisterFile<MicrocodeRegister> = RegisterFile((32..39).map { MicrocodeRegister(it) })
    override val muPC: MicrocodeRegister = MCR[0]
    override val muPL: SpecialSource = SpecialSource(29)
    override val zero: SpecialSource = SpecialSource(30)
    override val one: SpecialSource = SpecialSource(31)
    override val discard: SpecialDestination = SpecialDestination(63)
}