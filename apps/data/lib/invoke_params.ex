# Copyright 2022 Giuseppe De Palma, Matteo Trentin
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

defmodule Data.InvokeParams do
  @moduledoc """
    Struct representing the input parameteres when invoking a function.

    ## Fields
      - module: function module
      - function: function name
      - args: function arguments
  """
  @type t :: %__MODULE__{
          module: String.t(),
          function: String.t(),
          args: map()
        }
  @enforce_keys [:function]
  defstruct [:function, module: "_", args: %{}]
end
