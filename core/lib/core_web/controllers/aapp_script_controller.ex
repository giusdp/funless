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

defmodule CoreWeb.AAPPScriptController do
  use CoreWeb, :controller

  alias Core.Domain.AAPPScripts
  alias Core.Domain.Policies.Parsers
  alias Core.Schemas.AAPPScripts.AAPP

  action_fallback(CoreWeb.FallbackController)

  def index(conn, _params) do
    aapp_scripts = AAPPScripts.list_aapp_scripts()
    render(conn, :index, aapp_scripts: aapp_scripts)
  end

  def create(conn, %{"name" => script_name, "file" => %Plug.Upload{path: tmp_path}}) do
    with {:ok, aapp_script_string} <- File.read(tmp_path),
         {:ok, aapp_script} <- Parsers.AAPP.parse(aapp_script_string),
         {:ok, %AAPP{} = aapp_script} <-
           AAPPScripts.create_aapp_script(%{
             name: script_name,
             script: aapp_script |> Parsers.AAPP.to_map()
           }) do
      conn
      |> put_status(:created)
      |> render(:show, aapp_script: aapp_script)
    end
  end

  def create(_, _) do
    {:error, :bad_params}
  end

  def show(conn, %{"aapp_name" => name}) do
    aapp_script = AAPPScripts.get_aapp_script_by_name(name)
    render(conn, :show, aapp_script: aapp_script)
  end

  def update(conn, %{"id" => id, "aapp_script" => aapp_script_params}) do
    aapp_script = AAPPScripts.get_aapp_script!(id)

    with {:ok, %AAPP{} = aapp_script} <-
           AAPPScripts.update_aapp_script(aapp_script, aapp_script_params) do
      render(conn, :show, aapp_script: aapp_script)
    end
  end

  def delete(conn, %{"aapp_name" => name}) do
    case AAPPScripts.get_aapp_script_by_name(name) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "AAPP script not found"})

      aapp_script ->
        with {:ok, %AAPP{}} <- AAPPScripts.delete_aapp_script(aapp_script) do
          send_resp(conn, :no_content, "")
        end
    end
  end
end
