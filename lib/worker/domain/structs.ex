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

defmodule Worker.Domain.ExecutionResource do
  @moduledoc """
  A struct that represents a resource that can be used to execute a function.

  ## Fields
  - resource: the resource that can be used to execute a function
  """
  @type t :: %__MODULE__{
          resource: any()
        }
  @enforce_keys [:resource]
  defstruct [:resource]
end

defmodule Worker.Domain.FunctionStruct do
  @moduledoc """
    Function struct, passed to adapters.

    ## Fields
      - name: function name
      - namespace: function namespace, identifies the function along with the name
      - image: base image for the function's runtime
      - code: function code, used to initialize the runtime
  """
  @type t :: %__MODULE__{
          name: String.t(),
          image: String.t(),
          code: String.t(),
          namespace: String.t()
        }
  @enforce_keys [:name, :namespace]
  defstruct [:name, :image, :code, :namespace]
end
