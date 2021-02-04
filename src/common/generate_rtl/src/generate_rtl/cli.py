# Copyright (C) 2021 ETH Zurich and University of Bologna
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# SPDX-License-Identifier: Apache-2.0

import click
from pathlib import Path
from generate_permutation import generate_permutation


@click.command()
@click.argument('MEM_ROW_WIDTH', type=click.INT)
@click.option('-p', '--project_root', default=".", type=click.Path(exists=True, dir_okay=True, file_okay=False, writable=True))
def cli(mem_row_width, project_root):
    """Regenerates all automatically generated RTL functions in the project according to the given parameters"""
    #Generate final permutation in manipulator module
    project_root_path = Path(project_root)
    output_path = project_root_path/"src/hd_accelerator/hd_encoder/man_module/pkg_perm_final.sv"
    generate_permutation.generate_permutations(['-c', '1', '-o', str(output_path), str(mem_row_width), 'perm_final' ], standalone_mode=False)
    click.echo(f'Generating permutation verilog file for MAN module at: {output_path}')
    output_path = project_root_path/"src/hd_accelerator/hd_encoder/mixer/pkg_mixer_permutate.sv"
    generate_permutation.generate_permutations(['-c', '2', '-i', '-o', str(output_path), str(mem_row_width), 'mixer_permutate'], standalone_mode=False)
    click.echo(f'Generating permutation verilog file for mixer module at: {output_path}')

if __name__ == '__main__':
    cli()
