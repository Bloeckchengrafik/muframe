package muc

import muc.dsl.MucDsl
import muc.instrs.ar
import java.io.File

fun main() {
    MucDsl().run {
        ar()

        writeImages(File("../bin"))
    }
}
