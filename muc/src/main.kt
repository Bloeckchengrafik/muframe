package muc

import muc.dsl.MucDsl
import muc.instrs.ar

fun main() {
    MucDsl().run {
        ar()
    }
}
