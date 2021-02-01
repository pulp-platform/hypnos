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

import click
from jinja2 import Template
import numpy as np
from pathlib import Path

@click.command()
@click.option("-c", "--count", type=click.INT, default=1)
@click.argument("VECTOR_WIDTH", type=click.INT)
@click.argument("PACKAGENAME")
@click.argument("DISTRIBUTION", nargs=-1, type=click.FLOAT)
def gen_rand_vector(count, packagename, vector_width, distribution):
    """Generates a SystemVerilog package containing a single parameter of the type/name: logic[VECTORWIDTH-1:0] seed[COUNT].
    The generated vectors contains random bits. Optionally the probability of ones and zeros can be specified for each vector
    individually by suplying a list of values between [0,1].

    Example:

          gen_rand_vector -c 5  100 pkg_seeds 0.1 0.2 0.3 0.4 0.5

    This will generate 5 vectors of 100 bits. The first vectors probability of ones is 10%, 20% for the second vector and so on.
    If the number of specified probabilities is smaller than the number of vectors to generate (--count) a equal probability
    of ones and zeros is used for the remaining vectors."""


    seeds = [np.random.choice([1,0], vector_width, p=((distribution[i],1-distribution[i]) if i< len(distribution) else (0.5,0.5))) for i in range(count)]
    with open(Path(__file__).parent/'template.sv') as template_file:
        template = Template(template_file.read())
        with open(Path('{}.sv'.format(packagename)),'w+') as output_file:
            output_file.write(template.render(vector_width=vector_width, seeds=seeds, packagename=packagename))
        np.savez('{}.npz'.format(packagename),*seeds)
if __name__ == '__main__':
    gen_rand_vector()

