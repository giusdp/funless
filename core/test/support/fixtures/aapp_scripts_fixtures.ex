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

defmodule Core.AAPPScriptsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Core.AAPPScripts` context.
  """
  alias Core.Domain.AAPPScripts
  alias Core.Domain.Policies.Parsers.AAPP

  @doc """
  Generate an aapp_script.
  """
  def aapp_script_fixture(_attrs \\ %{}) do
    script = File.read!("test/support/fixtures/AAPP/example_aapp.yml")
    {:ok, parsed_script} = AAPP.parse(script)

    {:ok, aapp_script} =
      AAPPScripts.create_aapp_script(%{
        name: "exampleaappscript",
        script: parsed_script |> AAPP.to_map()
      })

    aapp_script
  end
end
