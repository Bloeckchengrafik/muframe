package muc.instrs

import muc.dsl.AluOp
import muc.dsl.Condition
import muc.dsl.MemoryAccess
import muc.dsl.MucDsl

fun MucDsl.ar() {
    rrType("ar", 0x1A) { p ->
        GPR[p.R1] load alu(GPR[p.R1], AluOp.Add, GPR[p.R2])
    }



    rrType("example", 0x42) { (R1, R2) ->
        val rd = Memory.read(GPR[R1], MCR[2], MemoryAccess.Async)

        MCR[1] load 3
        val loopBase = label()
        GPR[R1] load alu(GPR[R1], AluOp.Add, GPR[R2])
        MCR[1] load alu(MCR[1], AluOp.Sub, one) with updateFlags
        muPC load loopBase on Condition.NotEqual

        rd.await()

        GPR[R1] load alu(GPR[R1], AluOp.Add, MCR[2])
    }
}