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

defmodule CoreWeb.AAPPScriptJSON do
  alias Core.Schemas.AAPPScripts.AAPP

  @doc """
  Renders a list of aapp_scripts.
  """
  def index(%{aapp_scripts: aapp_scripts}) do
    %{data: for(aapp_script <- aapp_scripts, do: aapp_script.name)}
  end

  @doc """
  Renders a single aapp_script.
  """
  def show(%{aapp_script: aapp_script}) do
    %{data: data(aapp_script)}
  end

  defp data(%AAPP{} = aapp_script) do
    %{
      name: aapp_script.name,
      content: Jason.encode!(aapp_script.script)
    }
  end

  defp data(nil) do
    nil
  end
end
