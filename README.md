# Hypnos - A Hyperdimensional Computing Based Wake-up Circuit
Hypnos has the purpose to act as a smart wake-up circuit within larger SoCs. It
consists of an SPI master module, a lightweight general purpose digital
preprocessing block and an autonomous hardware accelerator for hyperdimensional
computing (HDC). The basic idea of this piece of hardware is to detect events of
interest within a continuous stream of digital data from external sensors
attached via SPI and trigger the wake-up line of an attached power management
module to wake up more powerfull and energy hungrier hardware.

The documentation of this module is still in its very early stage. More
information about hypnos' internals and the programming scheme for smart wake up
operation will follow.
## Project Structure
In the `src` directory you find the toplevel module `hypnos.sv` that instantiates the three major components of the SWU: 
- The programmable autonomous SPI master module (`src/spi_module/spi_top.sv`)
- A configurable lightweight Preprocessor module (`src/preprocessor/preprocessor_top.sv`)
- The Accelerator for Hyperdimensional computing (`src/hd_accelerator/hd_accelerator.sv`)

The HDC accelerator is fully parametric but it requires some random permutations to be auto-generated if its datawidth is changed. For purpose, there is a small python CLI tool in `src/common/generate_rtl` that generates the corresponding SystemVerilog files at the right project location. You can install the tool with (maybe in its own virtual environment if you don't want to clutter your main Python installation):
```
pip install -e src/common/generate_rtl
```
The run the CLI with:
```
hypnos_generate_rtl <HDC_ROW_WIDTH> -p <project_root>
```

`HDC_ROW_WIDTH` denotes the datapath with of the HDC accelerator which must
match the configuration settings chosen in the main configuration file
(`src/common/pkg_common.sv`). `project_root` should point to the root of this
git repository.
