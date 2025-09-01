# Copyright 2023 Giuseppe De Palma, Matteo Trentin
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

defmodule Data.Configurations.AAPP.Block do
  @moduledoc """
  Struct representing a block within an AAPP tag.
  Similar to APP.Block but with simplified affinity handling.
  """
  @type t :: %__MODULE__{
          strategy: :random | :"best-first" | :platform,
          workers: String.t() | [String.t()],
          invalidate: %{
            capacity_used: number() | :infinity,
            max_concurrent_invocations: number() | :infinity
          },
          affinity: [String.t()]
        }
  defstruct [
    :workers,
    affinity: [],
    strategy: :"best-first",
    invalidate: %{capacity_used: :infinity, max_concurrent_invocations: :infinity}
  ]
end

defmodule Data.Configurations.AAPP.Tag do
  @moduledoc """
  Struct representing a tag within an AAPP configuration.
  Similar to APP.Tag but uses AAPP.Block structs.
  """
  @type t :: %__MODULE__{
          blocks: [Data.Configurations.AAPP.Block.t()],
          followup: :default | :fail
        }
  defstruct [:blocks, followup: :fail]
end

defmodule Data.Configurations.AAPP do
  @moduledoc """
  Struct representing an AAPP (Advanced APP) configuration script.
  Similar to APP but with simplified affinity handling in blocks.
  """
  @type t :: %__MODULE__{
          tags: %{
            String.t() => Data.Configurations.AAPP.Tag.t()
          }
        }
  defstruct [:tags]
end