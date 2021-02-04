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
from jinja2 import Template
import numpy as np
from pathlib import Path

@click.command()
@click.option("-c", "--count", type=click.INT, default=1)
@click.option("-i", "--with-inverse", type=click.BOOL, default=False, is_flag=True)
@click.option("-o", "--output", type=click.Path(exists=False, file_okay=True, dir_okay=False, writable=True,readable=True))
@click.argument("VECTOR_WIDTH", type=click.INT)
@click.argument("FUNCTIONNAME")
def generate_permutations(count, functionname, vector_width, with_inverse, output):
    """Generates a SystemVerilog file containing a function with the given name that permutates the input vector randomly. """
    permutations = [np.random.permutation(range(0,vector_width)) for i in range(count)]
    inv_permutations = []
    if with_inverse:
        inv_permutations = [np.argsort(perm) for perm in permutations]
    with open(Path(__file__).parent/'template.sv') as template_file:
        template = Template(template_file.read())
        if not output:
            output= 'pkg_{}.sv'.format(functionname);
        with open(Path(output),'w+') as output_file:
            output_file.write(template.render(functionname=functionname,vector_width=vector_width, permutations=permutations, inv_permutations=inv_permutations))
        np.savez('{}_perm.npz'.format(functionname),*permutations)
        if with_inverse:
            np.savez('{}_inv_perm.npz'.format(functionname), *inv_permutations)
if __name__ == '__main__':
    generate_permutations()
