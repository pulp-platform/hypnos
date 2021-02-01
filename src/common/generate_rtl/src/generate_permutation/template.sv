//-----------------------------------------------------------------------------
// SPDX-License-Identifier: SHL-0.51
// Copyright (C) 2018-2021 ETH Zurich, University of Bologna
// Copyright and related rights are licensed under the Solderpad Hardware
// License, Version 0.51 (the "License"); you may not use this file except in
// compliance with the License. You may obtain a copy of the License at
// http://solderpad.org/licenses/SHL-0.51. Unless required by applicable law
// or agreed to in writing, software, hardware and materials distributed under
// this License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR
// CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//-----------------------------------------------------------------------------

package pkg_{{functionname}};
   function automatic logic[{{vector_width-1}}:0] {{functionname}}(input logic[{{vector_width-1}}:0] in, int version);
     unique case(version){% for permutation in permutations %}
       {{loop.index - 1}}: begin{% for index in permutation %}
         {{functionname}}[{{loop.index - 1}}] = in[{{index}}];
         {%- endfor %}
       end
       {%- endfor %}
     endcase
   endfunction

{% if inv_permutations|length %}
   function automatic logic[{{vector_width-1}}:0] {{functionname}}_inverse(input logic[{{vector_width-1}}:0] in, int version);
     unique case(version){% for inv_permutation in inv_permutations %}
       {{loop.index - 1}}: begin{% for index in inv_permutation %}
         {{functionname}}_inverse[{{loop.index - 1}}] = in[{{index}}];
         {%- endfor %}
       end
       {%- endfor %}
     endcase
   endfunction
{% endif %}
endpackage : pkg_{{functionname}}
