# Symbiyosys Experiments

FIFO refinement proof with Symbiyosys.

## Dependencies
- [Symbiyosys w/ Z3](https://symbiyosys.readthedocs.io/en/latest/install.html)

## Run
`sby -f verify.sby`

To force a failure, change the `WithOutputPatch` param in `verify.sv` to 0.

## Notes
The FIFO used comes from [OpenTitan](https://github.com/lowRISC/opentitan).
`prim_fifo_sync.v` is autogenerated from `prim_fifo_sync.sv` using
[sv2v](https://github.com/zachjs/sv2v): 
`sv2v -DFORMAL prim_fifo_sync.sv > prim_fifo_sync.v`
