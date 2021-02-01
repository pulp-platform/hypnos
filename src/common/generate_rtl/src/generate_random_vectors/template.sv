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

package {{packagename}};
{% if  seeds|length > 1 %}
    parameter logic[{{vector_width-1}}:0] seeds[{{seeds|length}}] = { {% for seed in seeds %}
        {{vector_width}}'b{%for bit in seed %}{{bit}}{% endfor %}{{ "," if not loop.last}}
    {%- endfor %}};
    {% else %}
    parameter logic[{{vector_width-1}}-1:0] seed = {{vector_width}}'b{{seeds[0]}};
    {% endif %}
endpackage : {{packagename}}
