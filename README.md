# muFrame

*A microcoded, System/360-inspired CPU architecture for FPGA experimentation.*

muFrame explores a simple idea: how much complexity can be moved from a CPU's control logic into a programmable microinstruction architecture?

The project combines a 48-bit microinstruction format with a Kotlin-based microassembler DSL, allowing instruction behavior to be expressed as typed register transfers, ALU operations, memory transactions, and conditional control flow.

```kotlin
val loop = label()

GPR[R1] load alu(GPR[R1], AluOp.Add, GPR[R2])
MCR[1] load alu(MCR[1], AluOp.Sub, one) with updateFlags
muPC load loop on Condition.NotEqual
```

The architecture is experimental and under active development. The microinstruction encoding is not yet stable, and hardware implementation is ongoing.

## License

If you want to use it (why would you? Srsly: please let me know over on [mastodon](https://social.tchncs.de/@bloeckchengrafik)) you are welcome to do so.

Any software part - for example the microassembler or example code - is licensed under the [MIT license](./LICENSE-SW.md).

Any hardware part - for example the RTL implementation - is licensed under the [CERN-OHL-P-2.0 license](./LICENSE-HW.md).

Generally if you find this useful, please let me know. Any feedback is appreciated!
